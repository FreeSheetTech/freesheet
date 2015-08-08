class CalculationError extends Error
  constructor: (@functionName, @message) ->

class FunctionError extends Error
  constructor: (@name, text, @error) ->
    @expr = {text}


module.exports = {CalculationError, FunctionError}