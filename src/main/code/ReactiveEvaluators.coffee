Rx = require 'rx'
_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
NotCalculated = 'NOT_CALCULATED'
Initial = 'INITIAL'
NoNewValue = 'NO_NEW_VALUE'

class Evaluator
  constructor: (@expr, @args) ->
    @subject = new Rx.BehaviorSubject
    @values = (Initial for i in [0...args.length])
    thisEval = this

    for arg, i in args
      @_subscribeToArg arg, i

    @_evaluateIfReady()

  observable: -> @subject

  _evaluateIfReady: ->
    haveAllValues = not _.some @values, (x) -> x is Initial
    if haveAllValues
      @subject.onNext @_calculateNextValue()

  _calculateNextValue: -> throw new Error('_calculateNextValue must be defined')

  _subscribeToArg: (arg, i) ->
    thisEval = this
    arg.observable().subscribe (value) ->
      thisEval.values[i] = value
      thisEval._evaluateIfReady()


class Literal extends Evaluator
  constructor: (expr, @value) ->
    super expr, []

  _calculateNextValue: -> @value

class CalcError extends Evaluator
  constructor: (error) ->
    super null, [error]
    @latest = error

  reset: -> @values = []
  resetChildExprs: ->

class Input extends Evaluator
  constructor: (expr, @inputName) ->
    @inputStream = inputStream = new Rx.BehaviorSubject(null)
    dummyArg = {observable: -> inputStream}
    super expr, [dummyArg]

  _calculateNextValue: ->
    @values[0]

  sendInput: (value) ->
    @inputStream.onNext value


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
    super expr, [@_makeSource(name)]
    if @userFunctions[name]
      @subject = new Rx.BehaviorSubject
      source = @userFunctions[name]
      source.subscribe @subject
    else
      source = @providedFunctions[name]
      value = source()
      @subject = new Rx.BehaviorSubject(value)

  _makeSource: (name) ->
    self = this
    observable: ->
      if self.userFunctions[name]
        self.userFunctions[name]
      else
        source = self.providedFunctions[name]
        value = source()
        new Rx.BehaviorSubject(value)


  _calculateNextValue: -> @values[0]

#TODO new values if function changes
class FunctionCallWithArgs extends Evaluator
  constructor: (expr, @name, args, @userFunctions, @providedFunctions) ->
    @func = @providedFunctions[name]
    super expr, args


  _calculateNextValue: -> @func.apply null, @values

class ArgRef
  constructor: (@name, @getArgValue) ->
  latestValue: ->
    result = @getArgValue @name
#    console.log 'ArgRef.latestValue', @name, result
    result

  newValues: ->  [@latestValue()]  #TODO is this good enough?
  hasNewValues: -> true #TODO is this good enough?
  reset: ->

class FunctionEvaluator # extends Evaluator
  constructor: (@funcDef, @name, @argNames, @evaluator, @argumentManager) ->

  latestValue: (argValues) ->
    @argumentManager.pushValues _.zipObject @argNames, argValues
    result = @evaluator.latestValue()
    @argumentManager.popValues()
#    console.log 'FunctionEvaluator.latestValue', @name, argValues, '->', result
    result

  newValues: (argValues) ->
    @evaluator.reset()
    @argumentManager.pushValues _.zipObject @argNames, argValues
#    result = @evaluator.newValues()
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
#      console.log 'TransformExpression.latestValue', _in, '->', result
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
  FunctionCallNoArgs, FunctionCallWithArgs, Input, Aggregation, Sequence, AggregationSelector, ArgRef, FunctionEvaluator, TransformExpression}