Rx = require 'rx'
{Literal, InfixExpression, FunctionCall} = require '../ast/Expressions'

module.exports = class ReactiveRunner
  VALUE = 'value'
  STREAM = 'stream'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @allChanges = new Rx.Subject()
    @userFunctionSubjects = {}

  output: (name) ->
    func = @userFunctions[name]
    stream = @_instantiateUserFunctionStream func
    stream

  addProvidedFunction: (name, fn) -> fn.kind = VALUE; @providedFunctions[name] = fn
  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedStreamFunction: (name, fn) -> fn.kind = STREAM; @providedFunctions[name] = fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    source = @_instantiateUserFunctionStream funcDef

    if subj = @userFunctionSubjects[name]
      subj.disp?.dispose()
      subj.disp = source.subscribe subj
    else
      subj = @userFunctionSubjects[name] = new Rx.BehaviorSubject(null)
      subj.disp = source.subscribe subj
      subj.subscribe (value) => @allChanges.onNext [name, value]


  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

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

  _instantiateProvidedFunctionStream: (func, argExprs) ->
    argStreams = (@_instantiateExprStream(a) for a in argExprs)
    result = switch func.kind
              when STREAM then func.apply null, argStreams
              when VALUE
                if argStreams.length then Rx.Observable.combineLatest argStreams, func
                else new Rx.BehaviorSubject func()
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
          when func = @userFunctions[name] then @_userFunctionSubject name
          when func = @providedFunctions[name] then @_instantiateProvidedFunctionStream func, expr.children
          else @_userFunctionSubject name

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _infixOperatorFunction: (operator) ->
    switch operator
      when '+' then (a, b) -> a + b
      when '-' then (a, b) -> a - b
      when '*' then (a, b) -> a * b
      when '/' then (a, b) -> a / b
      when '>' then (a, b) -> a > b
      when '>=' then (a, b) -> a >= b
      when '<' then (a, b) -> a < b
      when '<=' then (a, b) -> a <= b
      when '==' then (a, b) -> a == b
      when '<>' then (a, b) -> a != b
      else throw new Error("Unknown operator: " + operator)
