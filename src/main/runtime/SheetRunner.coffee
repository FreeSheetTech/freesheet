Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
SheetCodeGenerator = require '../code/SheetCodeGenerator'
{CalculationError, FunctionError} = require '../error/Errors'
Operations = require './Operations'
FunctionTypes = require './FunctionTypes'
_ = require 'lodash'

module.exports = class SheetRunner

  Invalid = '__INVALID__'

  withKind = (func, kind) -> func.kind = kind; func

  asImmediateFunction = (func) -> (s, f) ->
    results = []
    if _.isArray s
      seq = Rx.Observable.from s, null, null, Rx.Scheduler.immediate
      func(seq, f).subscribe (x) -> results.push x

    switch
      when func.returnKind == FunctionTypes.AGGREGATE_RETURN then _.last(results) ? null
      when func.returnKind == FunctionTypes.STREAM_RETURN then {_multipleValues: results }
      else results

  bufferedValueChangeStream = (valueChanges, trigger) ->
    collectChanges = (changes) -> _.zipObject(changes)
    valueChanges.buffer(-> trigger).map(collectChanges)

  errorFunction = (name, message) -> -> throw new CalculationError(name, "#{message}: " + name)
  unknownNameFunction = (name) -> errorFunction name, 'Unknown name'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @userFunctionSubjects = {}
    @userFunctionImpls = {}
    @inputs = {}
    @inputCompleteSubject = new Rx.Subject()
    @bufferedValueChanges = bufferedValueChangeStream @valueChanges, @inputCompleteSubject
    @slots = {}
    @events = []

    @sheet = _.assign {}, @providedFunctions, {
      operations: new Operations(null)
      stored: {}
      storedUpToDate: {}
    }


# TODO  rationalise this zoo of add...Functions
  _addProvidedFunction: (name, fn) ->
    @providedFunctions[name] = fn
    @sheet[name] = fn

  addProvidedFunction: (name, fn) ->
    switch
      when fn.kind is FunctionTypes.TRANSFORM_STREAM then @addProvidedTransformFunction name, fn
      when fn.returnKind is FunctionTypes.AGGREGATE_RETURN then @addProvidedAggregateFunction name, fn
      when fn.returnKind is FunctionTypes.SEQUENCE_RETURN then @addProvidedSequenceFunction name, fn
      when fn.returnKind is FunctionTypes.STREAM_RETURN then @addProvidedStreamReturnFunction name, fn
      else @_addProvidedFunction name, fn

  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap

  addProvidedTransformFunction: (name, fn) ->
    @_addProvidedFunction name, withKind(asImmediateFunction(fn), FunctionTypes.TRANSFORM)
    fn.kind = FunctionTypes.TRANSFORM_STREAM

  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap

  addProvidedStreamReturnFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    fn.returnKind = FunctionTypes.STREAM_RETURN

  addProvidedStreamReturnFunctions: (functionMap) -> @addProvidedStreamReturnFunction n, f for n, f of functionMap

  addProvidedSequenceFunction: (name, fn) -> @_addProvidedFunction name, asImmediateFunction(fn)
  addProvidedSequenceFunctions: (functionMap) -> @addProvidedSequenceFunction n, f for n, f of functionMap

  addProvidedAggregateFunction: (name, fn) ->
    @_addProvidedFunction name, asImmediateFunction(fn)
    fn.returnKind = FunctionTypes.AGGREGATE_RETURN

  addProvidedAggregateFunctions: (functionMap) -> @addProvidedAggregateFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    replacing = @userFunctions[name]?
    if replacing then @_invalidateDependents name
    @userFunctions[name] = funcDef
    functionImpl = SheetCodeGenerator.exprFunction funcDef, @_functionInfo()
    @userFunctionImpls[name] = functionImpl
    @sheet[name] = switch
      when _.includes(functionImpl.functionNames, name) then errorFunction name, 'Formula uses itself'
      when _.includes(@functionsUsedBy(name), name) then errorFunction name, 'Formula uses itself through another formula'
      when funcDef.argDefs.length is 0 then @_cachedValueFunction name, functionImpl.theFunction
      else functionImpl.theFunction

    if funcDef.expr instanceof Input then @inputs[name] = true

    @sheet[n] = unknownNameFunction(n) for n in functionImpl.functionNames when not @sheet[n]?
    if funcDef.argDefs.length is 0
      @slots[name] = Invalid
      @sheet.stored[name] = []
      @sheet.storedUpToDate[name] = true
      @sheet['all_' + name] = @_allFunction name


    @userFunctionSubjects[name] or (@userFunctionSubjects[name] = @_newUserFunctionSubject(name, @_sheetValue name))
    @_recalculate()

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    @_invalidateDependents functionName
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
      delete @slots[functionName]
      @sheet[functionName] = unknownNameFunction(functionName)
      @_recalculate()

  onValueChange: (callback, name) ->
    if name
      @valueChanges.subscribe (nameValue) -> if nameValue[0] == name then callback nameValue[0], nameValue[1]
      if subj = @userFunctionSubjects[name]
        callback name, subj.value
      else
        @sheet[name] = unknownNameFunction(name)
        @userFunctionSubjects[name] = @_newUserFunctionSubject name, @_sheetValue name
    else
      @valueChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  onBufferedValueChange: (callback) ->
    @bufferedValueChanges.subscribe (nameValueMap) -> callback n, v for n, v of nameValueMap

  onInputComplete: (callback) ->
    @inputCompleteSubject.subscribe -> callback()

  getInputs: -> (k for k, v of @inputs)

  sendInput: (name, value) ->
    @sendPartialInput name, value
    @inputComplete()

  sendPartialInput: (name, value) ->
    throw  new Error 'Unknown input name' unless @inputs[name]?
    @events.push [name, value]
    @_processEvents()

  sendDebugInput: (name, value) ->
    throw new Error 'Unknown value name' unless @userFunctions[name]?.argDefs.length is 0
    @events.push [name, value]
    @_processEvents()
    @inputComplete()

  inputComplete: ->
    @_recalculate()
    @inputCompleteSubject.onNext true

  hasUserFunction: (name) -> @userFunctions[name]?

  functionsUsedBy: (name) ->
    throw new Error "Unknown function name: #{name}" unless  @userFunctions[name]

    collectFunctions = (name, functionsCollectedSoFar) =>
      isAllFunction = !!name.match /^all_/
      plainName = name.replace /^all_/, ''
      return functionsCollectedSoFar if not @userFunctions[plainName] and !isAllFunction
      newFunctions = if isAllFunction then [plainName] else (n for n in @userFunctionImpls[name].functionNames when not _.includes functionsCollectedSoFar, n)
      functionsPlusNew = functionsCollectedSoFar.concat newFunctions
      newCalledFunctions = _.flatten(collectFunctions(n, functionsPlusNew) for n in newFunctions)
      _.uniq functionsPlusNew.concat(newCalledFunctions)

    collectFunctions name, []


  destroy: ->  @removeUserFunction n for n, f of @userFunctions

  #  private functions

  _queueEvents: (name, values) -> @events.push [name, v] for v in values

  _newUserFunctionSubject: (name, initialValue) ->
    subj = new Rx.BehaviorSubject(initialValue)
    subj.valueChangesSub = subj.distinctUntilChanged().subscribe (value) =>
      @valueChanges.onNext [name, value]
    subj

  _processEvents: -> @_processEvent @events.shift() while @events.length

  _processEvent: (event) ->
    [name, value] = event
    @slots[name] = value
    @_invalidateDependents name  #TODO only if value has changed?
    @_updateDependentAllValues name

  _invalidateDependents: (name) -> @slots[n] = Invalid for n in @_functionsUsing name

  _updateDependentAllValues: (name) ->
    # TODO     does every all_ value currently
    @sheet.storedUpToDate[k] = false for k,a of @sheet.stored
    for n, f of @sheet when n.match /^all_/
      f.apply(@sheet)


  _functionsUsing: (name) ->
    result = (n for n, f of @userFunctions when _.includes(@functionsUsedBy(n), name) or _.includes(@functionsUsedBy(n), 'all_' + name))
    result

  _recalculate: ->
    for name, subj of @userFunctionSubjects
      subj.onNext @_sheetValue name

  _sheetValue: (name) ->
    ops = new Operations name
    try
      @sheet[name].apply @sheet, []
    catch e
      ops._error e

  _allFunction: (name) ->
    runner = this
    ->
      storedValues = this.stored[name]
      if not this.storedUpToDate[name]
        storedValues.push runner._sheetValue(name)
        this.storedUpToDate[name] = true

      storedValues

  _cachedValueFunction: (name, calcFunction) ->
    runner = this
    ops = new Operations name
    ->
      if runner.slots[name] is Invalid
        calculated = ops._valueCheck calcFunction.apply runner.sheet, []
        if calculated?._multipleValues?
          runner.slots[name] = calculated._multipleValues[0] or null
          if calculated._multipleValues.length > 1 then runner._queueEvents name, calculated._multipleValues[1..]
        else
          runner.slots[name] = calculated

      runner.slots[name]

  _functionInfo: -> _.zipObject (([name, {kind: fn.kind, returnKind: fn.returnKind}] for name, fn of @providedFunctions when fn.kind or fn.returnKind))

