class CalculationError extends Error
  constructor: (@functionName, @message) ->

  fillName: (name) -> if @functionName then this else new CalculationError name, @message

  toString: -> "CalculationError - #{@functionName}: #{@message}"

class FunctionError extends Error
  constructor: (@name, text, @error) ->
    @expr = {text}


module.exports = {CalculationError, FunctionError}