Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'
JsCodeGenerator = require '../code/JsCodeGenerator'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
Operations = require './Operations'

module.exports = class ReactiveRunner
  @TRANSFORM = 'transform'
  @STREAM = 'stream'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @userFunctionSubjects = {}
    @inputStreams = {}

  # TODO  addProvidedFunction and addProvidedStream do the same thing
  addProvidedFunction: (name, fn) ->  @providedFunctions[name] = fn
  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedStream: (name, stream) -> @providedFunctions[name] = stream
  addProvidedStreams: (functionMap) -> @addProvidedStream n, s for n, s of functionMap
  addProvidedTransformFunction: (name, fn) -> fn.kind = ReactiveRunner.TRANSFORM; @providedFunctions[name] = fn
  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap
  addProvidedStreamFunction: (name, fn) -> fn.kind = ReactiveRunner.STREAM; @providedFunctions[name] = fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    source = @_userFunctionStream funcDef

    subj = @userFunctionSubjects[name] or (@userFunctionSubjects[name] = new Rx.BehaviorSubject(null))
    subj.sourceSub?.dispose()
    subj.sourceSub = source.subscribe subj
    if not subj.valueChangesSub
      subj.valueChangesSub = subj.subscribe (value) =>
        @valueChanges.onNext [name, value]

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    if subj = @userFunctionSubjects[functionName]
      subj.onNext(null)
      subj.sourceSub?.dispose()
      subj.sourceSub = null
      subj.valueChangesSub?.dispose()
      subj.valueChangesSub = null
      for subjName, subj of @userFunctionSubjects
        if not subj.hasObservers() then delete @userFunctionSubjects[subjName]

  onValueChange: (callback, name) ->
    if name
      @valueChanges.subscribe (nameValue) -> if nameValue[0] == name then callback nameValue[0], nameValue[1]
      if subj = @userFunctionSubjects[name]
        callback name, subj.value
      else
        @_newUserFunctionSubject name, null
    else
      @valueChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  getInputs: (name) -> (k for k, v of @inputStreams)

  sendInput: (name, value) -> @_inputStream(name).onNext value

  #  private functions

  _userFunctionSubject: (name) -> @userFunctionSubjects[name]
  _unknownUserFunctionSubject: (name) -> (@userFunctionSubjects[name] = @_newUserFunctionSubject(name, new CalculationError(name, "Unknown name")))
  _newUserFunctionSubject: (name, initialValue) ->
    subj = new Rx.BehaviorSubject(initialValue)
    subj.valueChangesSub = subj.subscribe (value) =>
      @valueChanges.onNext [name, value]
    subj

  _userFunctionStream: (func) ->
    {theFunction, functionNames} = JsCodeGenerator.exprFunction func.expr, @_functionInfo()
    ctx = {}
    ctx[n] = @_functionArg(n) for n in functionNames
    args = [new Operations(func.name, @_inputStream), ctx]
    theFunction.apply null, args

  _functionInfo: ->
    result = {}
    result[name] = {kind: fn.kind} for name, fn of @providedFunctions when fn.kind
    result

  _functionArg: (name) ->
    switch
      when func = @userFunctions[name] then @_userFunctionSubject name
      when (func = @providedFunctions[name])? and func.kind == ReactiveRunner.STREAM then func
      when func = @providedFunctions[name] then @_providedFunctionStream func
      else @_unknownUserFunctionSubject name

  _providedFunctionStream: (func) ->
    if func instanceof Rx.Observable or func instanceof Rx.Subject then func
    else
      if func.length then new Rx.BehaviorSubject func else new Rx.BehaviorSubject func()

  _inputStream: (name) => @inputStreams[name] or (@inputStreams[name] = new Rx.Subject)