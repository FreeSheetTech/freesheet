_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
NotCalculated = 'NOT_CALCULATED'
Initial = 'INITIAL'
NoNewValue = 'NO_NEW_VALUE'

class Evaluator
  constructor: (@expr, @values) ->
    @latest = NotCalculated

  newValues: ->
    if @values is Initial
      @values = @getInitialValues()
    else if @values is NotCalculated
      @values = @getNewValues()

    if @values.length
      @latest = @values[0]

#    console.log this.constructor.name, 'newValues', @expr.name, @values
    @values

  hasNewValues: -> !! @newValues().length

  latestValue: ->
    @newValues() #ensure use any new values
    if @latest is NotCalculated
      @latest = @getLatestValue()

#    console.log this.constructor.name, 'latestValue', @latest
    @latest

  getInitialValues: -> [@getLatestValue()]
  getNewValues: -> throw new Error('getNewValues must be defined')
  getLatestValue: -> throw new Error('getLatestValue must be defined')
  resetChildExprs: -> throw new Error('resetChildExprs must be defined')

  reset: ->
    @values = NotCalculated
    @resetChildExprs()

class Literal extends Evaluator
  constructor: (expr, value) ->
    super expr, [value]
    @latest = value

  reset: -> @values = []
  resetChildExprs: ->

class Error extends Evaluator
  constructor: (error) ->
    super null, [error]
    @latest = error

  reset: -> @values = []
  resetChildExprs: ->

class Input extends Evaluator
  constructor: (expr, @inputName, @getCurrentEvent) ->
    super expr, [null]
    @latest = null

  getNewValues: ->
    event = @getCurrentEvent()
    if event?.name is @inputName then [event.value] else []
  getLatestValue: -> throw new Error 'Input.getLatestValue should never be called'
  resetChildExprs: ->


class BinaryOperator extends Evaluator
  constructor: (expr, @left, @right) ->
    super expr, Initial

  op: (a, b) -> throw new Error('op must be defined')

  getNewValues: ->
    leftValues = @left.newValues()
    rightValues = @right.newValues()
    if leftValues.length or rightValues.length
      [@getLatestValue()]
    else []

  getLatestValue: ->
    leftVal = @left.latestValue()
    rightVal = @right.latestValue()
    switch
      when leftVal instanceof CalculationError then leftVal
      when rightVal instanceof CalculationError then rightVal
      else @op leftVal, rightVal

  hasNewValues: -> @left.hasNewValues() or @right.hasNewValues()

  resetChildExprs: ->
    @left.reset()
    @right.reset()


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
  constructor: (expr, @name, @sheet, @providedFunctions) -> super expr, Initial
  getNewValues: ->
    if @sheet[@name]?
      @sheet[@name].newValues()
    else
      []

  getLatestValue: ->
    if @sheet[@name]?
      @sheet[@name].latestValue()
    else
      providedFunction = @providedFunctions[@name]
      providedFunction.apply null, []

  resetChildExprs: ->



#TODO new values if function changes
class FunctionCallWithArgs extends Evaluator
  constructor: (expr, @name, @args, @sheet, @providedFunctions) ->
    super expr, Initial
    @previousData = {}

#  getInitialValues: -> [null]

  getNewValues: ->
    hasNewValuesForArgs = (a.hasNewValues() for a in @args)
    argsHaveNewValues =_.some(hasNewValuesForArgs, (a) -> a)

    argValues = (a.latestValue() for a in @args)
    functionHasNewValues = @sheet[@name]?.newValues(argValues).length

    result = if argsHaveNewValues or functionHasNewValues then [@getLatestValue()] else []
#    console.log 'FunctionCallWithArgs.getNewValues' , @name, argsHaveNewValues, functionHasNewValues, result
    result

  getLatestValue: ->
    argValues = (a.latestValue() for a in @args)
    if @sheet[@name]?
      result = @sheet[@name].latestValue(argValues)
    else
      providedFunction = @providedFunctions[@name]
      result = providedFunction.apply @previousData, argValues

#    console.log 'FunctionCallWithArgs.getLatestValue', @name, argValues, '->', result
    result

  resetChildExprs: -> a.reset() for a in @args

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
  constructor: (expr, @names, @items) -> super expr, Initial

  getNewValues: ->
    newValuesForItems = (i.newValues() for i in @items)
    if _.some(newValuesForItems, (i) -> i.length) then [@getLatestValue()] else []

  getLatestValue: ->
    itemValues = (i.latestValue() for i in @items)
    _.zipObject @names, itemValues

  resetChildExprs: -> i.reset() for i in @items


class Sequence extends Evaluator
  constructor: (expr, @items) -> super expr, Initial

  getNewValues: ->
    newValuesForItems = (i.newValues() for i in @items)
    if _.some(newValuesForItems, (i) -> i.length) then [@getLatestValue()] else []

  getLatestValue: -> (i.latestValue() for i in @items)

  resetChildExprs: -> i.reset() for i in @items


class AggregationSelector extends Evaluator
  constructor: (expr, @aggregation, @elementName) -> super expr, Initial

  getNewValues: ->
    newValuesForAgg = @aggregation.newValues()
    if newValuesForAgg.length then [@getLatestValue()] else []

  getLatestValue: -> @aggregation.latestValue()[@elementName]

  resetChildExprs: -> @aggregation.reset()


module.exports = {Literal, Error, Add, Subtract,Multiply, Divide, Eq, NotEq, Gt, Lt, GtEq, LtEq, And, Or,
  FunctionCallNoArgs, FunctionCallWithArgs, Input, Aggregation, Sequence, AggregationSelector, ArgRef, FunctionEvaluator, TransformExpression}