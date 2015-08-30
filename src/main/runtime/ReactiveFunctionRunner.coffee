Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
ReactiveFunctionGenerator = require '../code/ReactiveFunctionGenerator'
{CalculationError, FunctionError} = require '../error/Errors'
Eval = require '../code/ReactiveEvaluators'
Operations = require './Operations'
FunctionTypes = require './FunctionTypes'
_ = require 'lodash'

class ArgumentManager
  constructor: ->
    @stack = []

  getValue: (name) =>
    throw new Error('Call stack is empty') if not @stack.length
    currentArgs = @stack[0]
    throw new Error("Unknown argument name: #{name}") if not _.has currentArgs, name
    currentArgs[name]

  pushValues: (argMap) -> @stack.unshift argMap
  popValues: (argMap) -> @stack.shift


module.exports = class ReactiveFunctionRunner

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

  errorFunction = (name, message) -> new Eval.Error(new CalculationError name, "#{message}: #{name}")
  unknownNameFunction = (name) -> errorFunction name, 'Unknown name'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @userFunctionSubjects = {}
    @userFunctionImpls = {}
    @inputs = {}
    @inputCompleteSubject = new Rx.Subject()
    @bufferedValueChanges = bufferedValueChangeStream @valueChanges, @inputCompleteSubject
    @events = []
    @argumentManager = new ArgumentManager()
    @sheet = _.assign {}, @providedFunctions


# TODO  rationalise this zoo of add...Functions
  _addProvidedFunction: (name, fn) ->
    @providedFunctions[name] = fn
#    @sheet[name] = fn

  addProvidedFunction: (name, fn) ->
    switch
      when fn.kind is FunctionTypes.TRANSFORM_STREAM then @addProvidedTransformFunction name, fn
      when fn.returnKind is FunctionTypes.STREAM_RETURN then @addProvidedStreamReturnFunction name, fn
      else @_addProvidedFunction name, fn

  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap

  addProvidedTransformFunction: (name, fn) ->
    @_addProvidedFunction name, withKind(asImmediateFunction(fn), FunctionTypes.TRANSFORM)
    fn.kind = FunctionTypes.TRANSFORM_STREAM

  addProvidedTransformFunctions: (functionMap) -> @addProvidedTransformFunction n, f for n, f of functionMap

  addProvidedStreamReturnFunction: (name, fn) ->
    @_addProvidedFunction name, fn
    fn.returnKind = FunctionTypes.STREAM_RETURN

  addProvidedStreamReturnFunctions: (functionMap) -> @addProvidedStreamReturnFunction n, f for n, f of functionMap

  addUserFunction: (funcDef) ->
    name = funcDef.name
    @userFunctions[name] = funcDef
    functionImpl = ReactiveFunctionGenerator.exprFunction funcDef, @_functionInfo(), @userFunctionSubjects, @providedFunctions, @_getCurrentEvent, @argumentManager
    @userFunctionImpls[name] = functionImpl
    reactiveFunction = switch
      when _.includes(functionImpl.functionNames, name) then errorFunction name, 'Formula uses itself'
      when _.includes(@functionsUsedBy(name), name) then errorFunction name, 'Formula uses itself through another formula'
      else functionImpl.theFunction

    if funcDef.expr instanceof Input then @inputs[name] = reactiveFunction

#    @sheet[n] = unknownNameFunction(n) for n in functionImpl.functionNames when not @sheet[n]? and not @providedFunctions[n]?
    if funcDef.argDefs.length is 0
      context = {userFunctions: @userFunctionSubjects, providedFunctions: @providedFunctions}
      reactiveFunction.activate(context)
      subj = @userFunctionSubjects[name]
      if subj
        subj.sourceSub.dispose()
        source = reactiveFunction.observable()
        subj.sourceSub = source.subscribe subj
      else
        @userFunctionSubjects[name] = @_newUserFunctionSubject(name, reactiveFunction)
    else
      evalFunctionDefinition = new Eval.FunctionDefinition(funcDef.argNames(), reactiveFunction)
      subj = @userFunctionSubjects[name] or @userFunctionSubjects[name] = new Rx.BehaviorSubject()
      subj.onNext evalFunctionDefinition

#    @_recalculate()

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    @_invalidateDependents functionName
    delete @userFunctions[functionName]
    if subj = @userFunctionSubjects[functionName]
      subj.onNext(null)
      subj.valueChangesSub?.dispose()
      subj.valueChangesSub = null
      for subjName, subj of @userFunctionSubjects
        if not subj.hasObservers()
          delete @userFunctionSubjects[subjName]
          delete @userFunctionImpls[subjName]
      @_reset()
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
    throw  new Error 'Unknown input name' unless @inputs[name]?
    @inputs[name].sendInput value

  sendDebugInput: (name, value) ->
    throw new Error 'Unknown value name' unless @userFunctions[name]?.argDefs.length is 0
    @userFunctionSubjects[name].onNext value
    @userFunctionSubjects[name].onNext Eval.EvaluationComplete

  inputComplete: ->
    @_recalculate()
    @inputCompleteSubject.onNext true

  hasUserFunction: (name) -> @userFunctions[name]?

  functionsUsedBy: (name) ->
    throw new Error "Unknown function name: #{name}" unless  @userFunctions[name]

    collectFunctions = (name, functionsCollectedSoFar) =>
      return functionsCollectedSoFar if not @userFunctions[name]
      newFunctions =  (n for n in @userFunctionImpls[name].functionNames when not _.includes functionsCollectedSoFar, n)
      functionsPlusNew = functionsCollectedSoFar.concat newFunctions
      newCalledFunctions = _.flatten(collectFunctions(n, functionsPlusNew) for n in newFunctions)
      _.uniq functionsPlusNew.concat(newCalledFunctions)

    collectFunctions name, []


  destroy: ->  @removeUserFunction n for n, f of @userFunctions

  #  private functions

  _queueEvents: (name, values) -> @events.push [name, v] for v in values

  _newUserFunctionSubject: (name, reactiveFunction) ->
    source = reactiveFunction.observable()
    subj = new Rx.ReplaySubject(2)
    subj.sourceSub = source.subscribe subj
    logValueChange = (x)-> console.log 'value change', name, x
    notEvalComplete = (x)-> x isnt Eval.EvaluationComplete
    subj.valueChangesSub = subj.do(logValueChange).filter(notEvalComplete).distinctUntilChanged().subscribe (value) =>
      @valueChanges.onNext [name, value]
    subj

  _processEvents: -> @_processEvent @events.shift() while @events.length

  _processEvent: (event) ->
    [name, value] = event
    @_reset()
    @currentEvent = {name, value}
    @_invalidateDependents name  #TODO only if value has changed?
    @_recalculate()
    @currentEvent = null

  _invalidateDependents: (name) -> # ??? for n in @_functionsUsing name

  _functionsUsing: (name) ->
    result = (n for n, f of @userFunctions when _.includes(@functionsUsedBy(n), name) )
    result

  _reset: ->
    for n, f of @userFunctionImpls
      f.theFunction.reset()

  _recalculate: ->
    for name, subj of @userFunctionSubjects
      newVals = @_newValues name
      if (newVals.length) then subj.onNext @_sheetValue name

  _newValues: (name) ->
#    console.log '_newValues', name, @sheet[name]
    ops = new Operations name
    try
      @sheet[name].newValues()
    catch e
      ops._error e

  _sheetValue: (name) ->
    ops = new Operations name
    try
      @sheet[name].latestValue()
    catch e
      ops._error e

  _functionInfo: -> _.zipObject (([name, {kind: fn.kind, returnKind: fn.returnKind}] for name, fn of @providedFunctions when fn.kind or fn.returnKind))

  _getCurrentEvent: => @currentEvent