Rx = require 'rx'
_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
NotCalculated = 'NOT_CALCULATED'
Initial = 'INITIAL'
EvaluationComplete = 'EVALUATION_COMPLETE'

class Evaluator
  constructor: (@expr, @args, subj) ->
    @subject = subj or new Rx.ReplaySubject(2, null)
    @eventsInProgress = 0
    @values = (Initial for i in [0...args.length])

  observable: -> @subject

  activate: (context) ->
    @_subscribeTo arg.observable(), i for arg, i in @args
    @_activateArgs context


  _activateArgs: (context) -> arg.activate(context) for arg in @args

  _evaluateIfReady: ->
    if @eventsInProgress is 0
      haveAllValues = not _.some @values, (x) -> x is Initial
      if haveAllValues
        nextValue = @_calculateNextValue()
        console.log 'Send:', @toString(), nextValue
        @subject.onNext nextValue
        @subject.onNext EvaluationComplete


  _calculateNextValue: -> throw new Error('_calculateNextValue must be defined')

  _subscribeTo: (obs, i) ->
    thisEval = this
    obs.subscribe (value) ->
      if value is EvaluationComplete
        thisEval.eventsInProgress = thisEval.eventsInProgress - 1
        console.log 'Comp:', thisEval.toString(), value, ' -- events', thisEval.eventsInProgress
        thisEval._evaluateIfReady()
      else
        thisEval.eventsInProgress = thisEval.eventsInProgress + 1
        console.log 'Rcvd:', thisEval.toString(), value, '-- events', thisEval.eventsInProgress
        thisEval.values[i] = value

  toString: -> "#{@constructor.name} #{@expr?.text}"

class Literal extends Evaluator
  constructor: (expr, @value) ->
    @inputStream = inputStream = new Rx.Subject()
    dummyArg =
      observable: -> inputStream
      activate: ->
        inputStream.onNext value
        inputStream.onNext EvaluationComplete

    super expr, [dummyArg]

  _calculateNextValue: -> @value

class CalcError extends Evaluator
  constructor: (error) ->
    super null, [error]
    @latest = error

  reset: -> @values = []
  resetChildExprs: ->

class Input extends Evaluator
  constructor: (expr, @inputName) ->
    @inputStream = inputStream = new Rx.Subject()
    dummyArg =
      observable: -> inputStream
      activate: ->
        inputStream.onNext null
        inputStream.onNext EvaluationComplete

    super expr, [dummyArg]

  _calculateNextValue: ->
    @values[0]

  sendInput: (value) ->
    @inputStream.onNext value
    @inputStream.onNext EvaluationComplete

  toString: -> "#{@constructor.name} #{@inputName}"


class BinaryOperator extends Evaluator
  constructor: (expr, @left, @right) ->
    super expr, [@left, @right]

  _calculateNextValue: -> @op(@values[0], @values[1])

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
  constructor: (expr, @name, @userFunctions, @providedFunctions) ->
    super expr, [null]

  activate: ->
    obs = if @userFunctions[@name]
            @userFunctions[@name]
          else
            source = @providedFunctions[@name]
            value = source()
            new Rx.Observable.from([value, EvaluationComplete])
    @_subscribeTo obs, 0

  _calculateNextValue: -> @values[0]

#TODO new values if function changes
class FunctionCallWithArgs extends Evaluator
  constructor: (expr, @name, args) ->
    super expr, args

  activate: (context) ->
    @func = context.providedFunctions[@name]
    @_subscribeTo arg.observable(), i for arg, i in @args
    @_activateArgs context

  _calculateNextValue: ->
    console.log this, '_calculateNextValue', @values
    @func.apply null, @values

#TODO does this belong in here?
class FunctionDefinition
  constructor: (@argNames, @evaluatorTemplate) ->

class ArgRef extends Evaluator
  constructor: (@name) ->
    super name, [null]

  activate: (context) ->

  _calculateNextValue: -> @values[0]

class FunctionEvaluator # extends Evaluator
  constructor: (@funcDef, @name, @argNames, @evaluator, @argumentManager) ->

  latestValue: (argValues) ->
    @argumentManager.pushValues _.zipObject @argNames, argValues
    result = @evaluator.latestValue()
    @argumentManager.popValues()
    result

  newValues: (argValues) ->
    @evaluator.reset()
    @argumentManager.pushValues _.zipObject @argNames, argValues
    result = [@evaluator.latestValue()]
    @argumentManager.popValues()
    console.log 'FunctionEvaluator.newValues', @name, argValues, '->', result
    result

  reset: -> @evaluator.reset()

class TransformExpression
  constructor: (@expr, @evaluator, @argumentManager) ->

  latestValue: ->
    (_in) =>
      @evaluator.reset()
      @argumentManager.pushValues {'in': _in}
      result = @evaluator.latestValue()
      @argumentManager.popValues()
      result

  hasNewValues: -> @evaluator.hasNewValues()

  reset: -> @evaluator.reset()

class Aggregation extends Evaluator
  constructor: (expr, @names, @items) ->
    super expr, items

  _calculateNextValue: -> _.zipObject @names, @values

class Sequence extends Evaluator
  constructor: (expr, @items) ->
    super expr, items

  _calculateNextValue: -> @values


class AggregationSelector extends Evaluator
  constructor: (expr, @aggregation, @elementName) ->
    super expr, [aggregation]

  _calculateNextValue: -> @values[0][@elementName]

module.exports = {Literal, Error, Add, Subtract,Multiply, Divide, Eq, NotEq, Gt, Lt, GtEq, LtEq, And, Or,
  FunctionCallNoArgs, FunctionCallWithArgs, Input, Aggregation, Sequence, AggregationSelector, ArgRef, FunctionEvaluator, TransformExpression, EvaluationComplete, FunctionDefinition}