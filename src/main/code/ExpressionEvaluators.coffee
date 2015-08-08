_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
NotCalculated = 'NOT_CALCULATED'

class Evaluator
  constructor: (@expr, @values) ->
    @latest = NotCalculated

  newValues: ->
    if @values is NotCalculated
      @values = @getNewValues()
    if @values.length
      @latest = @values[0]

    #    console.log 'newValues', this
    @values

  latestValue: ->
    @newValues() #ensure use any new values
    if @latest is NotCalculated
      @latest = @getLatestValue()

    #    console.log 'latestValue', this
    @latest

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
    super expr, [@getLatestValue()]

  op: (a, b) -> throw new Error('op must be defined')

  getNewValues: ->
    leftValues = @left.newValues()
    rightValues = @right.newValues()
    if leftValues.length or rightValues.length
      [@getLatestValue()]
    else []

  getLatestValue: -> @op @left.latestValue(), @right.latestValue()
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
  constructor: (@expr, @name, @sheet, @providedFunctions) -> super expr, [@getLatestValue()]
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
  constructor: (@expr, @name, @args, @sheet, @providedFunctions) -> super expr, [@getLatestValue()]

  getNewValues: ->
    newValuesForArgs = (a.newValues() for a in @args)
    if _.some(newValuesForArgs, (a) -> a.length) then [@getLatestValue()] else []

  getLatestValue: ->
    providedFunction = @providedFunctions[@name]
    argValues = (a.latestValue() for a in @args)
    providedFunction.apply null, argValues

  resetChildExprs: -> a.reset() for a in @args



module.exports = {Literal, Add, Subtract,Multiply, Divide, Eq, NotEq, Gt, Lt, GtEq, LtEq, And, Or, FunctionCallNoArgs, FunctionCallWithArgs, Input}