_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'
NotCalculated = 'NOT_CALCULATED'

class Evaluator
  constructor: (@expr) ->
    @values = NotCalculated
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

  reset: -> @values = NotCalculated

class Literal extends Evaluator
  constructor: (expr, value) ->
    super expr
    @values = [value]
    @latest = value

  reset: -> @values = []


class BinaryOperator extends Evaluator
  constructor: (expr, @left, @right) -> super expr

  op: (a, b) -> throw new Error('op must be defined')

  getNewValues: ->
    leftValues = @left.newValues()
    rightValues = @right.newValues()
    if leftValues.length or rightValues.length
      [@op(@left.latestValue(), @right.latestValue())]
    else []

  getLatestValue: -> @op @left.latestValue(), @right.latestValue()

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
  op: (a, b) -> a - b

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

class FunctionCallNoArgs extends Evaluator
  constructor: (@expr, @name, @sheet) -> super expr
  getNewValues: -> @sheet[@name].newValues()
  getLatestValue: -> @sheet[@name].latestValue()

module.exports = {Literal, Add, Subtract,Multiply, Divide, Eq, NotEq, Gt, Lt, GtEq, LtEq, And, Or, FunctionCallNoArgs}