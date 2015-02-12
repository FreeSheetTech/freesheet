Rx = require 'rx'
{Literal, InfixExpression, FunctionCall} = require '../ast/Expressions'

class ReactiveRunner
  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @allChanges = new Rx.Subject()
    @userFunctionSubjects = {}

  output: (name) ->
    func = @userFunctions[name]
    stream = @_instantiateUserFunctionStream func
    stream

  addProvidedFunction: (name, fn) -> @providedFunctions[name] = fn
  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap

  addUserFunction: (name, funcDef) ->
    @userFunctions[name] = funcDef
    source = @_instantiateUserFunctionStream funcDef

    if subj = @userFunctionSubjects[name]
      subj.disp?.dispose()
      subj.disp = source.subscribe subj
    else
      subj = @userFunctionSubjects[name] = new Rx.BehaviorSubject(null)
      subj.disp = source.subscribe subj
      subj.subscribe (value) => @allChanges.onNext [name, value]


  addUserFunctions: (funcDefMap) -> @addUserFunction n, f for n, f of funcDefMap

  onChange: (callback, name) ->
    if name
      subj = @_userFunctionSubject name
      subj.subscribe (value) -> callback name, value
    else
      @allChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  #  private functions

  _userFunctionSubject: (name) -> @userFunctionSubjects[name] or (@userFunctionSubjects[name] = @_newUserFunctionSubject(name))
  _newUserFunctionSubject: (name) ->
    subj = new Rx.BehaviorSubject(null)
    subj.subscribe (value) => @allChanges.onNext [name, value]
    subj

  _instantiateUserFunctionStream: (func) ->
    @_instantiateExprStream func.expr

  _instantiateProvidedFunctionStream: (func) ->
    result = func.call null, []
    result

  _instantiateExprStream: (expr) ->
    switch
      when expr instanceof Literal
        new Rx.BehaviorSubject(expr.value)
      when expr instanceof InfixExpression
        leftObs = @_instantiateExprStream expr.children[0]
        rightObs = @_instantiateExprStream expr.children[1]
        Rx.Observable.combineLatest leftObs, rightObs, @_infixOperatorFunction(expr.operator)

      when expr instanceof FunctionCall
        name = expr.functionName
        switch
          when func = @userFunctions[name] then @_instantiateUserFunctionStream func
          when provided = @providedFunctions[name] then @_instantiateProvidedFunctionStream provided
          else throw new Error "Unknown function: " + name

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _infixOperatorFunction: (operator) ->
    switch operator
      when '+' then (a, b) -> a + b
      when '-' then (a, b) -> a - b
      when '/' then (a, b) -> a / b
      else throw new Error("Unknown operator: " + operator)

module.exports = {ReactiveRunner}