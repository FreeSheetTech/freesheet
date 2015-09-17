Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
ReactiveFunctionGenerator = require '../code/ReactiveFunctionGenerator'
{CalculationError, FunctionError} = require '../error/Errors'
Eval = require '../code/ReactiveEvaluators'
FunctionTypes = require './FunctionTypes'
_ = require 'lodash'

module.exports = class ReactiveFunctionRunner

  withKind = (func, kind) -> func.kind = kind; func

  asImmediateFunction = (func) ->
    (s, f) ->
      arr = s or []     #TODO initial null
      func arr, f

  calcError = (name, message) -> new CalculationError name, "#{message}: #{name}"
  errorFunction = (name, expr, message) -> new Eval.CalcError(expr, calcError(name, message))
  unknownNameFunction = (name) -> errorFunction name, null, 'Unknown name'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @valueChanges = new Rx.Subject()
    @newValues = new Rx.Subject()
    @userFunctionSubjects = {}
    @userFunctionImpls = {}
    @inputs = {}

  _addProvidedFunction: (name, fn) ->
    @providedFunctions[name] = fn

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
    functionImpl = ReactiveFunctionGenerator.exprFunction funcDef, @_functionInfo(), @userFunctionSubjects, @providedFunctions
    @userFunctionImpls[name] = functionImpl
    reactiveFunction = switch
      when _.includes(functionImpl.functionNames, name) then errorFunction name, funcDef.expr, 'Formula uses itself'
      when _.includes(@functionsUsedBy(name), name) then errorFunction name, funcDef.expr, 'Formula uses itself through another formula'
      else functionImpl.theFunction

    if funcDef.expr instanceof Input then @inputs[name] = reactiveFunction

    if funcDef.argDefs.length is 0
      unknownName = (name) =>
        unknownError = unknownNameFunction(name)
        unknownError.activate({})
        @userFunctionSubjects[name] = @_newUserFunctionSubject(name, unknownError)
      context = {localEvals: {}, userFunctions: @userFunctionSubjects, providedFunctions: @providedFunctions, unknownName}
      reactiveFunction.activate(context)
      subj = @userFunctionSubjects[name]
      if subj
        subj.sourceSub.dispose()
        source = reactiveFunction.observable()
        subj.sourceSub = source.subscribe subj
        if not subj.valueChangesSub
          @_subscribeValueChanges name, subj

      else
        @userFunctionSubjects[name] = @_newUserFunctionSubject(name, reactiveFunction)
    else
      evalFunctionDefinition = new Eval.FunctionDefinition(funcDef.argNames(), reactiveFunction)
      subj = @userFunctionSubjects[name] or @userFunctionSubjects[name] = new Rx.BehaviorSubject()
      subj.onNext evalFunctionDefinition

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (functionName) ->
    delete @userFunctions[functionName]
    @userFunctionImpls[functionName]?.theFunction.deactivate()
    console.log 'removeUserFunction', functionName
    if subj = @userFunctionSubjects[functionName]
      subj.onNext calcError functionName, 'Unknown name'
      subj.onNext Eval.EvaluationComplete
      subj.sourceSub?.dispose()
      subj.valueChangesSub?.dispose()
      subj.valueChangesSub = null
      subj.newValuesSub?.dispose()
      subj.newValuesSub = null
      subj.currentValueSubscription?.dispose()
      subj.currentValueSubscription = null
      for subjName, s of @userFunctionSubjects
        console.log subjName, 'observers:', s.observers.length
        console.log subjName, 'current value observers:', s.currentValueSubj.observers.length
        if not s.hasObservers()
          delete @userFunctionSubjects[subjName]
          delete @userFunctionImpls[subjName]

  onValueChange: (callback, name) ->
    if name
      @valueChanges.subscribe (nameValue) -> if nameValue[0] == name then callback nameValue[0], nameValue[1]
      if subj = @userFunctionSubjects[name]
        callback name, subj.currentValueSubj.value   #TODO hack - relies on internal implementation of BehaviorSubject
      else
        unknown = unknownNameFunction(name)
        unknown.activate {}
        subj = @userFunctionSubjects[name] = @_newUserFunctionSubject name, unknown
    else
      @valueChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  onNewValue: (callback, name) ->
    if name
      @newValues.filter( (nv) -> nv[0] == name).subscribe (nameValue) -> callback nameValue[0], nameValue[1]
    else
      @newValues.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  getInputs: -> (k for k, v of @inputs)

  sendInput: (name, value) ->
    throw  new Error 'Unknown input name' unless @inputs[name]?
    @inputs[name].sendInput value

  sendDebugInput: (name, value) ->
    throw new Error 'Unknown value name' unless @userFunctions[name]?.argDefs.length is 0
    @userFunctionSubjects[name].onNext value
    @userFunctionSubjects[name].onNext Eval.EvaluationComplete

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

  _newUserFunctionSubject: (name, reactiveFunction) ->
    source = reactiveFunction.observable()
    subj = new Rx.ReplaySubject(2)
    subj.sourceSub = source.subscribe subj
    @_subscribeValueChanges name, subj
    subj

  _subscribeValueChanges: (name, subj) ->
    logValueChange = (x)-> # console.log 'value change', name, x
    notEvalComplete = (x)-> x isnt Eval.EvaluationComplete
    compareValue = (x, y) -> _.isEqual x, y
    fillErrorName = (x) -> if x instanceof CalculationError then x.fillName(name) else x
    subj.currentValueSubj = new Rx.BehaviorSubject(null)
    allValues = subj.do(logValueChange).filter(notEvalComplete).map(fillErrorName)
    subj.currentValueSubscription = allValues.subscribe subj.currentValueSubj
    subj.valueChangesSub = subj.currentValueSubj.distinctUntilChanged(null, compareValue).subscribe (value) =>
        @valueChanges.onNext [name, value]
    subj.newValuesSub = allValues.subscribe (value) =>
        @newValues.onNext [name, value]
    console.log '_subscribeValueChanges', name, 'observers:', subj.observers.length

  _functionInfo: -> _.zipObject (([name, {kind: fn.kind, returnKind: fn.returnKind}] for name, fn of @providedFunctions when fn.kind or fn.returnKind))