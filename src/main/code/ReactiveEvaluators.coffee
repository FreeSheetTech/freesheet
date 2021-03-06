Rx = require 'rx'
_ = require 'lodash'
Period = require '../functions/Period'
FunctionTypes = require '../runtime/FunctionTypes'
{CalculationError} = require '../error/Errors'
Updated = 'UPDATED'
Initial = 'INITIAL'
NotUsed = 'NOTUSED'
EvaluationComplete = 'EVALUATION_COMPLETE'

nextId = 1

trace = (x...) -> # console.log x...

internalSource = (initialValue) ->
  subj = new Rx.Subject()
  subject: subj
  observable: -> subj
  activate: ->
    if initialValue isnt undefined
      subj.onNext initialValue
      subj.onNext EvaluationComplete
  deactivate: ->


class Evaluator
  constructor: (@expr, @args, subj) ->
    @id = "[#{nextId++}]"
    @subject = subj or new Rx.ReplaySubject(2, null)
    @eventsInProgress = (false for i in [0...args.length])
    @values = (Initial for i in [0...args.length])
    @isTemplate = false
    @argSubscriptions = []

  observable: -> @subject

  activate: (context) ->
    @isTemplate = context.isTemplate or false
    @_subscribeTo arg.observable(), i for arg, i in @args
    @_activateArgs context

  deactivate: ->
    trace 'deactivate:', @expr.text
    s.dispose() for s in @argSubscriptions
    arg?.deactivate() for arg in @args

  copy: -> throw new Error("copy must be defined in #{@toString()}")
  currentValue: (argValues) ->
    throw new Error("currentValue not available: #{@name}") if @values[0] is Initial
    @values[0]

  _activateArgs: (context) -> arg.activate(context) for arg in @args

  _evaluateIfReady: ->
    haveAllValues = not _.some @values, (x) -> x is Initial
    errorInValues = _.find @values, (x) -> x instanceof CalculationError
    if haveAllValues
      nextValue = switch
        when errorInValues then errorInValues
        when @isTemplate then Updated
        else @_calculateCheckNextValue()
      trace 'Send:', @toString(), nextValue
      @subject.onNext nextValue
      @subject.onNext EvaluationComplete

  _calculateCheckNextValue: ->
    try
      value = @_calculateNextValue()
      switch
        when value == Number.POSITIVE_INFINITY or value == Number.NEGATIVE_INFINITY then throw new Error 'Divide by zero'
        when _.isNaN value then throw new Error 'Invalid values in calculation'
        else value
    catch e
      if e instanceof CalculationError then e else new CalculationError(null, e.message)


  _calculateNextValue: -> throw new Error('_calculateNextValue must be defined')
  _currentValues: (argValues) -> (a.currentValue(argValues) for a in @args)

  _subscribeTo: (obs, i) ->
    thisEval = this
    subscription = obs.subscribe (value) ->
      if value is EvaluationComplete
        eventsWereInProgress = _.some thisEval.eventsInProgress
        thisEval.eventsInProgress[i] = false
        trace 'Comp:', thisEval.toString(), value, ' -- events', thisEval.eventsInProgress, ' -- values', thisEval.values
        eventsAreNowInProgress = _.some thisEval.eventsInProgress
        if eventsWereInProgress and not eventsAreNowInProgress then thisEval._evaluateIfReady()
      else
        thisEval.eventsInProgress[i] = true
        trace 'Rcvd:', thisEval.toString(), value, '-- events', thisEval.eventsInProgress
        thisEval.values[i] = value

    @argSubscriptions.push subscription

  toString: -> "#{@constructor.name} #{@expr?.text} #{@id}#{if @isTemplate then ' T' else ''}"

class Literal extends Evaluator
  constructor: (expr, @value) -> super expr, [internalSource value]

  copy: -> new Literal @expr, @value
  currentValue: (argValues) -> @value

  _calculateNextValue: -> @value

class CalcError extends Evaluator
  constructor: (expr, @error) -> super expr, [internalSource error]

  copy: -> new CalcError @expr, @error
  currentValue: (argValues) -> @error

  _calculateNextValue: -> @error

class Input extends Evaluator
  constructor: (expr, @inputName) -> super expr, [@inputSource = internalSource()]

  copy: -> new Input @expr, @inputName
  currentValue: (argValues) -> @values[0]

  _calculateNextValue: -> @values[0]

  sendInput: (value) ->
    @inputSource.subject.onNext value
    @inputSource.subject.onNext EvaluationComplete

  toString: -> "#{@constructor.name} #{@inputName}"


class BinaryOperator extends Evaluator
  constructor: (expr, @left, @right) ->
    super expr, [@left, @right]

  _calculateNextValue: -> @op(@values[0], @values[1])

  copy: -> new @constructor @expr, @left.copy(), @right.copy()
  currentValue: (argValues) -> @op(@left.currentValue(argValues), @right.currentValue(argValues))

  op: (a, b) -> throw new Error('op must be defined')

class Add extends BinaryOperator
  op: (a, b) ->
    switch
      when a instanceof Period and b instanceof Period
        new Period(a.millis + b.millis)
      when a instanceof Date and b instanceof Period
        new Date(a.getTime() + b.millis)
      when _.isPlainObject(a) and _.isPlainObject(b)
        _.merge {}, a, b
      when _.isArray(a) and _.isArray(b)
        a.concat b
      else
        a + b


class Subtract extends BinaryOperator
  op: (a, b) ->
    switch
      when a instanceof Date and b == null or a == null and b instanceof Date
        null
      when a instanceof Period and b instanceof Period
        new Period(a.millis - b.millis)
      when a instanceof Date and b instanceof Date
        new Period(a.getTime() - b.getTime())
      when a instanceof Date and b instanceof Period
        new Date(a.getTime() - b.millis)
      else
        a - b


class Multiply extends BinaryOperator
  op: (a, b) -> a * b

class Divide extends BinaryOperator
  op: (a, b) -> a / b

class Eq extends BinaryOperator
  op: (a, b) -> a == b

class NotEq extends BinaryOperator
  op: (a, b) -> a != b

class Gt extends BinaryOperator
  op: (a, b) -> a > b

class GtEq extends BinaryOperator
  op: (a, b) -> a >= b

class Lt extends BinaryOperator
  op: (a, b) -> a < b

class LtEq extends BinaryOperator
  op: (a, b) -> a <= b

class And extends BinaryOperator
  op: (a, b) -> a && b

class Or extends BinaryOperator
  op: (a, b) -> a || b

#TODO new values if function changes
class FunctionCallNoArgs extends Evaluator
  constructor: (expr, @name) ->
    super expr, [null]

  activate: (context) ->
    log = (x) => trace 'Pass:', @toString(), x
    storeValue = (x) => if x isnt EvaluationComplete then @values[0] = x
    if evaluator = context.localEvals[@name]
      obs = evaluator.observable()
      @funcSubscription = obs.do(storeValue).do(log).subscribe @subject
      @funcEval = evaluator
    else if source = context.userFunctions[@name]
      obs = source
      @funcSubscription = obs.do(storeValue).do(log).subscribe @subject
    else if source = context.providedFunctions[@name]
      value = source()
      obs = new Rx.Observable.from([value, EvaluationComplete])
      @_subscribeTo obs, 0
    else
      obs = context.unknownName(@name)
      @funcSubscription = obs.do(storeValue).do(log).subscribe @subject

  deactivate: -> @funcSubscription?.dispose()

  copy: -> new FunctionCallNoArgs @expr, @name
  currentValue: (argValues) -> @funcEval?.currentValue(argValues) or @values[0]

  _calculateNextValue: -> @values[0]

#TODO new values if function changes
#TODO ensure deactivate unsubscribes everything
class FunctionCallWithArgs extends Evaluator
  constructor: (expr, @name, args) ->
    super expr, args

  activate: (context) ->
    if @func = context.userFunctions[@name]
      @isUserFunction = true
      @context = context
      @func.subscribe @_updateFunction
    else if @func = context.providedFunctions[@name]
      @isUserFunction = false
      if @func.kind == FunctionTypes.STREAM_RETURN
        @_subscribeStreamFunction @func
      else
        @_subscribeTo arg.observable(), i for arg, i in @args
    else
      @isUserFunction = true
      @func = context.unknownName(@name)
      @context = context
      @func.subscribe @_updateFunction

    @_activateArgs context

  copy: -> new FunctionCallWithArgs @expr, @name, (a.copy() for a in @args)
  currentValue: (argValues) ->
    functionArgs = @_currentValues(argValues)
    if @isUserFunction
      funcArgValues = _.zipObject @funcDef.argNames, functionArgs
      result = @evaluator.currentValue(funcArgValues)
    else
      if @func.kind == FunctionTypes.STREAM_RETURN then throw new Error("Unexpected call to currentValue for stream return function in #{@toString()}")
      result = @func.apply null, functionArgs

#    console.log @toString(), argValues, functionArgs, result
    result

  _updateFunction: (update) =>
    if (update instanceof FunctionDefinition)
      funcDef = update
      @funcDef = funcDef
      s.dispose() for s in @argSubscriptions
      @argSubscriptions = []
      @evaluator?.deactivate()

      subjects = (arg.observable() for arg in @args)
      argSubjects = _.zipObject funcDef.argNames, subjects
      @evaluator = funcDef.evaluatorTemplate.copy()
      contextWithArgs = _.merge {}, @context, {argSubjects}
      @evaluator.activate(contextWithArgs)
      @_subscribeTo @evaluator.observable(), 0
      #TODO hack
      @values[i] = null for i in [1...@args.length]
    else
      if update isnt EvaluationComplete then @values[0] = update
      @values[i] = null for i in [1...@args.length]
      @_evaluateIfReady()



  _subscribeStreamFunction: (fn) ->
    #TODO requires function to handle EvaluationComplete
    rawArgObs = (arg.observable() for arg in @args)
    outputObs = fn.apply null, rawArgObs
    outputObs.subscribe @subject

  _calculateNextValue: ->
    trace @toString(), '_calculateNextValue', @values
    if @isUserFunction
      @values[0]
    else
      @func.apply null, @values

#TODO does this belong in here?
class FunctionDefinition
  constructor: (@argNames, @evaluatorTemplate) ->

class ArgRef extends Evaluator
  constructor: (@name) ->
    super {text: name}, [null]

  activate: (context) ->
    obs = context.argSubjects[@name]
    @_subscribeTo obs, 0

  copy: -> new ArgRef @name
  currentValue: (argValues) -> if _.has(argValues, @name) then argValues[@name] else @values[0]

  _calculateNextValue: -> @values[0]

class Aggregation extends Evaluator
  constructor: (expr, @names, @items) ->
    super expr, items
    @localValues = []

  _activateArgs: (context) ->
    thisEval = this
    localEvals = _.zipObject @names, @args
    contextWithLocal = _.merge {}, context, {localEvals}
    super contextWithLocal

  copy: -> new Aggregation @expr, @names, (a.copy() for a in @items)
  currentValue: (argValues) ->
    currentValues = @_currentValues(argValues)
    trace 'Aggregation.currentValue', argValues, currentValues, @localValues
    _.zipObject @names, currentValues

  _calculateNextValue: ->
    trace 'Aggregation._calculateNextValue',  @values
    _.zipObject @names, @values

class Sequence extends Evaluator
  constructor: (expr, @items) ->
    super expr, items

  copy: -> new Sequence @expr, (a.copy() for a in @items)
  currentValue: (argValues) -> @_currentValues(argValues)

  _calculateNextValue: -> @values


class AggregationSelector extends Evaluator
  constructor: (expr, @aggregation, @elementName) ->
    super expr, [aggregation]

  copy: -> new AggregationSelector @expr, @aggregation.copy(), @elementName
  currentValue: (argValues) ->
    currVal = @aggregation.currentValue(argValues)
    (currVal and currVal[@elementName]) or null

  _calculateNextValue: ->
    (@values[0] and @values[0][@elementName]) or null

class ExpressionFunction extends Evaluator
  constructor: (@evaluator) ->
    super evaluator.expr, []

  activate: (context) ->
    @context = context
    @_subscribeTo @evaluator.observable(), 0
    exprContext =
      localEvals: context.localEvals
      userFunctions: context.userFunctions
      providedFunctions: context.providedFunctions
      unknownName: context.unknownName
      argSubjects: _.merge {'in': Rx.Observable.from([null, EvaluationComplete])}, context.argSubjects

    @evaluator.activate exprContext


  copy: -> new ExpressionFunction @evaluator.copy()

  currentValue: (argValues) ->
    evaluator = @evaluator
    currentArgValues = _.merge {}, argValues
#    console.log 'EF currentValue', evaluator.toString(), 'values', @values, 'argValues', argValues

    (_in) ->
      functionArgValues = _.merge {'in': _in}, currentArgValues
      result  = evaluator.currentValue functionArgValues
#      console.log 'EF currentValue function', evaluator.toString(), "functionArgValues", functionArgValues, "result", result
      result

  _calculateNextValue: ->
    evaluator = @evaluator
#    console.log 'EF _calculateNextValue', evaluator.toString(), 'values', @values

    (_in) ->
      result  = evaluator.currentValue {'in': _in}
#      console.log 'EF function', evaluator.toString(), "in", _in, "result", result
      result

module.exports = {Literal, CalcError, Add, Subtract,Multiply, Divide, Eq, NotEq, Gt, Lt, GtEq, LtEq, And, Or,
  FunctionCallNoArgs, FunctionCallWithArgs, Input, Aggregation, Sequence, AggregationSelector, ArgRef,
  EvaluationComplete, FunctionDefinition, ExpressionFunction}