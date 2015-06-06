class CalculationError extends Error
  constructor: (@functionName, @message) ->

module.exports = {CalculationError}