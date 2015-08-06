NotCalculated = 'NOT_CALCULATED'

class Literal
  constructor: (@expr, @value) ->
    @values = [@value]
    @latest = @value

  newValues: ->
#    console.log 'newValues', this
    @values

  latestValue: -> @latest

  reset: -> @values = []

class BinaryOperator
  constructor: (@expr, @left, @right) ->
    @values = NotCalculated
    @latest = NotCalculated

  op: (a, b) -> throw new Error('op must be defined')

  newValues: ->
    if @values is NotCalculated
      leftValues = @left.newValues()
      rightValues = @right.newValues()
      if leftValues.length or rightValues.length
        @values = [@op(@left.latestValue(), @right.latestValue())]
        @latest = NotCalculated
    @values

  latestValue: ->
    @newValues() #ensure use any new values
    if @latest is NotCalculated
      @latest = @op @left.latestValue(), @right.latestValue()
    @latest

  reset: -> @values = NotCalculated

class Add extends BinaryOperator
  op: (a, b) -> a + b

class Subtract extends BinaryOperator
  op: (a, b) -> a - b

class FunctionCallNoArgs
  constructor: (@expr, @name, @sheet) ->
    @values = NotCalculated
    @latest = NotCalculated

  newValues: ->
    if @values is NotCalculated
      @values = @sheet[@name].newValues()
      if @values.length
        @latest = NotCalculated

    #    console.log 'newValues', this
    @values

  latestValue: ->
    @newValues() #ensure use any new values
    if @latest is NotCalculated
      @latest = @sheet[@name].latestValue()

    #    console.log 'latestValue', this
    @latest

  reset: -> @values = NotCalculated

module.exports = {Literal, Add, Subtract, FunctionCallNoArgs}