Rx = require 'rx'
{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'
JsCodeGenerator = require '../code/JsCodeGenerator'
Period = require '../functions/Period'
Operations = require './Operations'

aggregateFunction = (childNames) ->
  () ->
    result = {}  #TODO use lodash zip etc
    result[childNames[i]] = arguments[i] for i in [0...childNames.length]
    result

sequenceFunction = () -> (arguments[i] for i in [0...arguments.length])

module.exports = class ReactiveRunner
  @VALUE = 'value'
  @STREAM = 'stream'
  @TRANSFORM = 'transform'

  constructor: (@providedFunctions = {}, @userFunctions = {}) ->
    @allChanges = new Rx.Subject()
    @userFunctionSubjects = {}

  output: (name) ->
    func = @userFunctions[name]
    stream = @_userFunctionStream func
    stream

  addProvidedFunction: (name, fn) ->  @providedFunctions[name] = fn
  addProvidedFunctions: (functionMap) -> @addProvidedFunction n, f for n, f of functionMap
  addProvidedValueFunction: (name, fn) -> fn.kind = ReactiveRunner.VALUE; @providedFunctions[name] = fn
  addProvidedValueFunctions: (functionMap) -> @addProvidedValueFunction n, f for n, f of functionMap
  addProvidedStreamFunction: (name, fn) -> fn.kind = ReactiveRunner.STREAM; @providedFunctions[name] = fn
  addProvidedStreamFunctions: (functionMap) -> @addProvidedStreamFunction n, f for n, f of functionMap
  addProvidedTransformFunction: (name, fn) -> fn.kind = ReactiveRunner.TRANSFORM; @providedFunctions[name] = fn
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
    codeGen = new JsCodeGenerator(func.expr)
    functionCallNames = (fc.functionName for fc in codeGen.functionCalls)
    console.log 'codeGen.code', codeGen.code
    functionBody = "return " + codeGen.code
    functionCreateArgs = [null].concat('operations', functionCallNames, functionBody)
    innerCombineFunction = new (Function.bind.apply(Function, functionCreateArgs));
    combineFunction = () ->
      argArray = (arguments[i] for i in [0..arguments.length])
      args = [Operations].concat(argArray)
      innerCombineFunction.apply(null, args)
    if codeGen.functionCalls.length
      Rx.Observable.combineLatest @_exprStreams(codeGen.functionCalls), combineFunction
    else
      new Rx.BehaviorSubject combineFunction()


  _providedFunctionStream: (func) ->

    result = switch func.kind
              when ReactiveRunner.STREAM then func
              when ReactiveRunner.TRANSFORM then func
              when ReactiveRunner.VALUE
                if func.length then new Rx.BehaviorSubject func
                else new Rx.BehaviorSubject func()
              else throw new Error("Unknown function kind:" + func.kind)

    result

  _exprStream: (expr) ->
    switch
#      when expr instanceof Literal
#        new Rx.BehaviorSubject(expr.value)
#
#      when expr instanceof InfixExpression
#        codeGen = new JsCodeGenerator(expr)
#        functionCallNames = (fc.functionName for fc in codeGen.functionCalls)
#        console.log 'codeGen.code', codeGen.code
#        functionBody = "return " + codeGen.code
#        functionCreateArgs = [null].concat('operations', functionCallNames, functionBody)
#        innerCombineFunction = new (Function.bind.apply(Function, functionCreateArgs));
#        combineFunction = () ->
#          argArray = (arguments[i] for i in [0..arguments.length])
#          args = [Operations].concat(argArray)
#          innerCombineFunction.apply(null, args)
#        if codeGen.functionCalls.length
#          Rx.Observable.combineLatest @_exprStreams(codeGen.functionCalls), combineFunction
#        else
#          new Rx.BehaviorSubject combineFunction()
#
#
#      when expr instanceof Aggregation
#        Rx.Observable.combineLatest @_exprStreams(expr.children), aggregateFunction(expr.childNames)
#
#      when expr instanceof Sequence
#        Rx.Observable.combineLatest @_exprStreams(expr.children), sequenceFunction
#
#      when expr instanceof AggregationSelector
#        @_exprStream(expr.aggregation).map (x) -> el = expr.elementName; x?[el]

      when expr instanceof FunctionCall
        name = expr.functionName
        switch
          when func = @userFunctions[name] then @_userFunctionSubject name
          when func = @providedFunctions[name] then @_providedFunctionStream func
          else @_userFunctionSubject name

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _exprStreams: (exprs) -> (@_exprStream(e) for e in exprs)

  _functionStream: (expr) ->
    codeGen = new JsCodeGenerator(expr, 'context')

    functionGenerator = createFunctionGenerator(codeGen.code, codeGen.functionCalls)
    if codeGen.functionCalls.length
      Rx.Observable.combineLatest @_exprStreams(codeGen.functionCalls), functionGenerator
    else
      new Rx.BehaviorSubject functionGenerator()

  createFunctionGenerator = (expressionCode, functionCalls) ->
    () ->
      args = arguments
      argValue = (functionCall) ->
        argPos = functionCalls.indexOf(functionCall)
        args[argPos]

      context = {}
      context[f.functionName] = argValue(f) for f in functionCalls  #TODO use lodash?
      functionBody = "return #{expressionCode};"
      console.log "Generated function:\n", functionBody, "\n"
      console.log "Context:", context, "\n\n"
      innerFunction = new Function('_in', 'operations', 'context', functionBody)
      transformFunction = (_in) -> innerFunction _in, Operations, context
      transformFunction

  asVarName = (functionCall) -> functionCall.functionName

  asLiteral = (value) -> JSON.stringify value
