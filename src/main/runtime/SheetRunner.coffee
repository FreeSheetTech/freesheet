Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'
SheetCodeGenerator = require '../code/SheetCodeGenerator'
Period = require '../functions/Period'
{CalculationError, FunctionError} = require '../error/Errors'
Operations = require './Operations'
_ = require 'lodash'

module.exports = class SheetRunner
  @TRANSFORM = 'transform'
  @STREAM = 'stream'
  @TRANSFORM_STREAM = 'transformStream'
  @SEQUENCE_RETURN = 'sequenceReturn'
  @STREAM_RETURN = 'streamReturn'
  @AGGREGATE_RETURN = 'aggregateReturn'

  isRxObservable = (func) -> typeof func.subscribe == 'function'
  returnsStream = (func) -> func.kind == SheetRunner.STREAM or func.kind == SheetRunner.TRANSFORM_STREAM or func.returnKind == SheetRunner.STREAM_RETURN or func.returnKind == SheetRunner.SEQUENCE_RETURN
  returnsAggregate = (func) -> func.returnKind == SheetRunner.AGGREGATE_RETURN
  withKind = (func, kind) -> func.kind = kind; func

  asImmediateFunction = (func) -> (s, f) ->
    results = []
    seq = Rx.Observable.from s, null, null, Rx.Scheduler.immediate
    func(seq, f).subscribe (x) -> results.push x
    if returnsAggregate(func) then _.last results else results

  bufferedValueChangeStream = (valueChanges, trigger) ->
    collectChanges = (changes) -> _.zipObject(changes)
    valueChanges.buffer(-> trigger).map(collectChanges)

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @userFunctionSubjects = {}
    @userFunctionImpls = {}
    @inputStreams = {}
    @inputCompleteSubject = new Rx.Subject()
    @bufferedValueChanges = bufferedValueChangeStream @valueChanges, @inputCompleteSubject

    @sheet = _.assign {}, @providedFunctions, {operations: new Operations("a function", @_inputStream)
    }

  # TODO  rationalise this zoo of add...Functions
  _addProvidedFunction: (name, fn) ->
    @providedFunctions[name] = fn
    @sheet[name] = fn

  addProvidedFunction: (name, fn) ->
    switch
      when fn.kind is SheetRunner.TRANSFORM_STREAM then @addProvidedTransformFunction name, fn
      when fn.returnKind is SheetRunner.AGGREGATE_RETURN then @addProvidedAggregateFunction name, fn
      when fn.returnKind is SheetRunner.SEQUENCE_RETURN then @addProvidedSequenceFunction name, fn
      else @_addProvidedFunction name, fn

  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedStream: (name, stream) -> @providedFunctions[name] = stream
  addProvidedStreams: (functionMap) -> @addProvidedStream n, s for n, s of functionMap

  addProvidedTransformFunction: (name, fn) ->
    @_addProvidedFunction name, withKind(asImmediateFunction(fn), SheetRunner.TRANSFORM)
    @_addProvidedFunction name + 'Over', withKind(fn, SheetRunner.TRANSFORM_STREAM)

  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap

  addProvidedStreamFunction: (name, fn) -> fn.kind = SheetRunner.STREAM; @_addProvidedFunction name, fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap
  addProvidedStreamReturnFunction: (name, fn) -> fn.returnKind = SheetRunner.STREAM_RETURN; @_addProvidedFunction name, fn
  addProvidedStreamReturnFunctions: (functionMap) -> @addProvidedStreamReturnFunction n, f for n, f of functionMap

  addProvidedSequenceFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    @addProvidedStreamFunction name + 'Over', fn

  addProvidedSequenceFunctions: (functionMap) -> @addProvidedSequenceFunction n, f for n, f of functionMap

  addProvidedAggregateFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    fn.returnKind = SheetRunner.AGGREGATE_RETURN
    @addProvidedStreamFunction name + 'Over', fn

  addProvidedAggregateFunctions: (functionMap) -> @addProvidedAggregateFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    functionImpl = SheetCodeGenerator.exprFunction funcDef, @_functionInfo()
    @userFunctionImpls[name] = functionImpl
    @sheet[name] = functionImpl.theFunction

    initValue = @_sheetValue name
    subj = @userFunctionSubjects[name] or (@userFunctionSubjects[name] = new Rx.BehaviorSubject(initValue))
    #    subj.sourceSub?.dispose()
    #    source = @_userFunctionStream funcDef, functionImpl.theFunction, functionImpl.functionNames
    #    subj.sourceSub = source.subscribe subj
    if not subj.valueChangesSub
      subj.valueChangesSub = subj.distinctUntilChanged().subscribe (value) =>
        @valueChanges.onNext [name, value]

    @_recalculate()
#    if not subj.observeStream then subj.observeStream = subj.observeOn Rx.Scheduler.timeout

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    delete @userFunctions[functionName]
    if subj = @userFunctionSubjects[functionName]
      subj.onNext(null)
#      subj.sourceSub?.dispose()
#      subj.sourceSub = null
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
        @userFunctionSubjects[name] = @_newUserFunctionSubject name, null
    else
      @valueChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  onBufferedValueChange: (callback) ->
    @bufferedValueChanges.subscribe (nameValueMap) -> callback n, v for n, v of nameValueMap

  onInputComplete: (callback) ->
    @inputCompleteSubject.subscribe -> callback()

  getInputs: -> (k for k, v of @inputStreams)

  sendInput: (name, value) ->
    @sendPartialInput name, value
    @inputComplete()

  sendPartialInput: (name, value) ->
    stream = @inputStreams[name]
    throw   new Error 'Unknown input name' unless stream
    stream.onNext value

  inputComplete: ->
    @_recalculate()
    @inputCompleteSubject.onNext true

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

  _recalculate: ->
    for name, subj of @userFunctionSubjects
      subj.onNext @_sheetValue name

  _sheetValue: (name) ->
    @sheet[name].apply @sheet, []

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
      theFunction.apply(null, args) #.observeOn(Rx.Scheduler.currentThread)
    catch e
      new Rx.BehaviorSubject( new FunctionError func.name, 'Sorry - this formula cannot be used')

  _functionInfo: -> _.zipObject (([name, {kind: fn.kind, returnKind: fn.returnKind}] for name, fn of @providedFunctions when fn.kind or fn.returnKind))

  _functionArg: (name) ->
    switch
      when func = @userFunctions[name] then @_userFunctionSubject(name) #.observeStream
      when func = @providedFunctions[name] then @_providedFunctionStream func
      else @_unknownUserFunctionSubject name

  _providedFunctionStream: (func) ->
    switch
      when returnsStream(func) then func
      when isRxObservable(func) then func
      when func.length then new Rx.BehaviorSubject func
      else new Rx.BehaviorSubject func()

  _inputStream: (name) => @inputStreams[name] or (@inputStreams[name] = new Rx.BehaviorSubject(null))

