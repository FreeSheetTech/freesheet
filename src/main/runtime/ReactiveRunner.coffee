Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'
JsCodeGenerator = require '../code/JsCodeGenerator'
Period = require '../functions/Period'
Operations = require './Operations'

module.exports = class ReactiveRunner
  @TRANSFORM = 'transform'
  @STREAM = 'stream'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @allChanges = new Rx.Subject()
    @userFunctionSubjects = {}

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
    if not subj.allChangesSub
      subj.allChangesSub = subj.subscribe (value) => @allChanges.onNext [name, value]

  addUserFunctions: (funcDefList) -> @addUserFunction f for f in funcDefList

  removeUserFunction: (name) ->
    if subj = @userFunctionSubjects[name]
      subj.onNext(null)
      subj.sourceSub?.dispose()
      subj.sourceSub = null
      subj.allChangesSub?.dispose()
      subj.allChangesSub = null
      for name, subj of @userFunctionSubjects
        if not subj.hasObservers() then delete @userFunctionSubjects[name]

  onChange: (callback, name) ->
    if name
      @allChanges.subscribe (nameValue) -> if nameValue[0] == name then callback nameValue[0], nameValue[1]
      if subj = @userFunctionSubjects[name]
        callback name, subj.value
      else
        @_newUserFunctionSubject name
    else
      @allChanges.subscribe (nameValue) -> callback nameValue[0], nameValue[1]

  #  private functions

  _userFunctionSubject: (name) -> @userFunctionSubjects[name] or (@userFunctionSubjects[name] = @_newUserFunctionSubject(name))
  _newUserFunctionSubject: (name) ->
    subj = new Rx.BehaviorSubject(null)
    subj.allChangesSub = subj.subscribe (value) => @allChanges.onNext [name, value]
    subj

  _userFunctionStream: (func) ->
    {theFunction, functionNames} = JsCodeGenerator.exprFunction func.expr, @_functionInfo()
    args = [Operations].concat (@_functionArg(n) for n in functionNames)
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
      else @_userFunctionSubject name

  _providedFunctionStream: (func) ->
    if func instanceof Rx.Observable or func instanceof Rx.Subject then func
    else
      if func.length then new Rx.BehaviorSubject func else new Rx.BehaviorSubject func()
