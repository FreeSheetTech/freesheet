Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'
JsCodeGenerator = require '../code/JsCodeGenerator'
Period = require '../functions/Period'
{CalculationError, FunctionError} = require '../error/Errors'
Operations = require './Operations'
_ = require 'lodash'

module.exports = class ReactiveRunner
  @TRANSFORM = 'transform'
  @STREAM = 'stream'
  @TRANSFORM_STREAM = 'transformStream'
  @SEQUENCE_RETURN = 'sequenceReturn'
  @STREAM_RETURN = 'streamReturn'
  @AGGREGATE_RETURN = 'aggregateReturn'

  isRxObservable = (func) -> typeof func.subscribe == 'function'
  returnsStream = (func) -> func.kind == ReactiveRunner.STREAM or func.kind == ReactiveRunner.TRANSFORM_STREAM or func.returnKind == ReactiveRunner.STREAM_RETURN or func.returnKind == ReactiveRunner.SEQUENCE_RETURN
  returnsAggregate = (func) -> func.returnKind == ReactiveRunner.AGGREGATE_RETURN

  asImmediateFunction = (func) -> (s) ->
    results = []
    seq = Rx.Observable.from s, null, null, Rx.Scheduler.immediate
    func(seq).subscribe (x) -> results.push x
    if returnsAggregate(func) then _.last results else results

  asImmediateTransformFunction = (func) ->
    immFn = (s, f) ->
      results = []
      seq = Rx.Observable.from s, null, null, Rx.Scheduler.immediate
      func(seq, f).subscribe (x) -> results.push x
      results

    immFn.kind = ReactiveRunner.TRANSFORM
    immFn

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @userFunctionSubjects = {}
    @userFunctionImpls = {}
    @inputStreams = {}

  # TODO  rationalise this zoo of add...Functions
  _addProvidedFunction: (name, fn) ->  @providedFunctions[name] = fn
  addProvidedFunction: (name, fn) ->
    switch
      when fn.returnKind is ReactiveRunner.AGGREGATE_RETURN then @addProvidedAggregateFunction name, fn
      when fn.returnKind is ReactiveRunner.SEQUENCE_RETURN then @addProvidedSequenceFunction name, fn
      else @_addProvidedFunction name, fn

  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedStream: (name, stream) -> @providedFunctions[name] = stream
  addProvidedStreams: (functionMap) -> @addProvidedStream n, s for n, s of functionMap

  addProvidedTransformFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateTransformFunction fn
    fn.kind = ReactiveRunner.TRANSFORM_STREAM
    @_addProvidedFunction name + 'Over', fn

  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap

  addProvidedStreamFunction: (name, fn) -> fn.kind = ReactiveRunner.STREAM; @providedFunctions[name] = fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap
  addProvidedStreamReturnFunction: (name, fn) -> fn.returnKind = ReactiveRunner.STREAM_RETURN; @providedFunctions[name] = fn
  addProvidedStreamReturnFunctions: (functionMap) -> @addProvidedStreamReturnFunction n, f for n, f of functionMap

  addProvidedSequenceFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    @addProvidedStreamFunction name + 'Over', fn

  addProvidedSequenceFunctions: (functionMap) -> @addProvidedSequenceFunction n, f for n, f of functionMap

  addProvidedAggregateFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    fn.returnKind = ReactiveRunner.AGGREGATE_RETURN
    @addProvidedStreamFunction name + 'Over', fn

  addProvidedAggregateFunctions: (functionMap) -> @addProvidedAggregateFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    functionImpl = JsCodeGenerator.exprFunction funcDef, @_functionInfo()
    @userFunctionImpls[name] = functionImpl
    source = @_userFunctionStream funcDef, functionImpl.theFunction, functionImpl.functionNames

    subj = @userFunctionSubjects[name] or (@userFunctionSubjects[name] = new Rx.BehaviorSubject(null))
    subj.sourceSub?.dispose()
    subj.sourceSub = source.subscribe subj
    if not subj.valueChangesSub
      subj.valueChangesSub = subj.subscribe (value) =>
        @valueChanges.onNext [name, value]

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    delete @userFunctions[functionName]
    if subj = @userFunctionSubjects[functionName]
      subj.onNext(null)
      subj.sourceSub?.dispose()
      subj.sourceSub = null
      subj.valueChangesSub?.dispose()
      subj.valueChangesSub = null
      for subjName, subj of @userFunctionSubjects
        if not subj.hasObservers()
          delete @userFunctionSubjects[subjName]
          delete @userFunctionImpls[subjName]

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

  sendInput: (name, value) ->
    stream = @inputStreams[name]
    throw   new Error 'Unknown input name' unless stream
    stream.onNext value

  sendDebugInput: (name, value) ->
    stream = @_userFunctionSubject(name)
    throw new Error 'Unknown name' unless stream
    stream.onNext value

  hasUserFunction: (name) -> @_userFunctionSubject(name)?

  functionsUsedBy: (name, functionsCollectedSoFar = []) ->
    return functionsCollectedSoFar if not @userFunctions[name]
    funcImpl = @userFunctionImpls[name]
    throw new Error "Unknown function name: #{name}" unless funcImpl
    newFunctions = (n for n in funcImpl.functionNames when not _.includes functionsCollectedSoFar, n)
    functionsPlusNew = functionsCollectedSoFar.concat newFunctions
    newCalledFunctions = _.flatten(@functionsUsedBy(n, functionsPlusNew) for n in newFunctions)
    functionsPlusNew.concat _.uniq(newCalledFunctions)


  destroy: ->  @removeUserFunction n for n, f of @userFunctions

  #  private functions

  _userFunctionSubject: (name) -> @userFunctionSubjects[name]
  _unknownUserFunctionSubject: (name) -> (@userFunctionSubjects[name] = @_newUserFunctionSubject(name, new CalculationError(name, "Unknown name")))
  _newUserFunctionSubject: (name, initialValue) ->
    subj = new Rx.BehaviorSubject(initialValue)
    subj.valueChangesSub = subj.subscribe (value) =>
      @valueChanges.onNext [name, value]
    subj

  _userFunctionStream: (func, theFunction, functionNames) ->
    if _.includes(functionNames, func.name) then return new Rx.BehaviorSubject( new CalculationError func.name, 'Formula uses itself')
    if _.includes(@functionsUsedBy(func.name), func.name) then return new Rx.BehaviorSubject( new CalculationError func.name, 'Formula uses itself through another formula')
    ctx = {} # TODO use zipObject
    ctx[n] = @_functionArg(n) for n in functionNames
    args = [new Operations(func.name, @_inputStream), ctx]
    try
      theFunction.apply null, args
    catch e
      new Rx.BehaviorSubject( new FunctionError func.name, 'Sorry - this formula cannot be used')

  _functionInfo: -> _.zipObject (([name, {kind: fn.kind, returnKind: fn.returnKind}] for name, fn of @providedFunctions when fn.kind or fn.returnKind))

  _functionArg: (name) ->
    switch
      when func = @userFunctions[name] then @_userFunctionSubject name
      when func = @providedFunctions[name] then @_providedFunctionStream func
      else @_unknownUserFunctionSubject name

  _providedFunctionStream: (func) ->
    switch
      when returnsStream(func) then func
      when isRxObservable(func) then func
      when func.length then new Rx.BehaviorSubject func
      else new Rx.BehaviorSubject func()

  _inputStream: (name) => @inputStreams[name] or (@inputStreams[name] = new Rx.BehaviorSubject(null))
