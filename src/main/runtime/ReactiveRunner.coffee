Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall} = require '../ast/Expressions'

infixOperatorFunction = (operator) ->
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

aggregateFunction = (childNames) ->
  () ->
    result = {}  #TODO use lodash zip etc
    result[childNames[i]] = arguments[i] for i in [0...childNames.length]
    result

sequenceFunction = () -> (arguments[i] for i in [0...arguments.length])


module.exports = class ReactiveRunner
  VALUE = 'value'
  STREAM = 'stream'
  TRANSFORM = 'transform'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @allChanges = new Rx.Subject()
    @userFunctionSubjects = {}

  output: (name) ->
    func = @userFunctions[name]
    stream = @_userFunctionStream func
    stream

  addProvidedFunction: (name, fn) -> fn.kind = VALUE; @providedFunctions[name] = fn
  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedStreamFunction: (name, fn) -> fn.kind = STREAM; @providedFunctions[name] = fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap
  addProvidedTransformFunction: (name, fn) -> fn.kind = TRANSFORM; @providedFunctions[name] = fn
  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    source = @_userFunctionStream funcDef

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

  _userFunctionStream: (func) ->
    @_exprStream func.expr

  _providedFunctionStream: (func, argExprs) ->
    argStreams = null
    if func.kind == TRANSFORM
      argStreams =  [@_exprStream(argExprs[0]), @_functionStream(argExprs[1])]
    else
      argStreams = (@_exprStream(a) for a in argExprs)

    result = switch func.kind
              when STREAM then func.apply null, argStreams
              when TRANSFORM
                Rx.Observable.combineLatest argStreams, func
              when VALUE
                if argStreams.length then Rx.Observable.combineLatest argStreams, func
                else new Rx.BehaviorSubject func()
              else throw new Error("Unknown function kind:" + func.kind)

    result

  _exprStream: (expr) ->
    switch
      when expr instanceof Literal
        new Rx.BehaviorSubject(expr.value)

      when expr instanceof InfixExpression
        Rx.Observable.combineLatest @_exprStreams(expr.children), infixOperatorFunction(expr.operator)

      when expr instanceof Aggregation
        Rx.Observable.combineLatest @_exprStreams(expr.children), aggregateFunction(expr.childNames)

      when expr instanceof Sequence
        Rx.Observable.combineLatest @_exprStreams(expr.children), sequenceFunction

      when expr instanceof FunctionCall
        name = expr.functionName
        switch
          when func = @userFunctions[name] then @_userFunctionSubject name
          when func = @providedFunctions[name] then @_providedFunctionStream func, expr.children
          else @_userFunctionSubject name

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _exprStreams: (exprs) -> (@_exprStream(e) for e in exprs)

  _functionStream: (expr) ->
    stream = @_exprStream expr
    stream.map (val) -> new Function("return #{val};")

