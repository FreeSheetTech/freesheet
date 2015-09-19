class FunctionDefinition
  constructor: (@name, @argNames) ->

class UserFunction extends FunctionDefinition
  constructor: (name, argNames, @expr) ->
    super name, argNames

module.exports = {FunctionDefinition, UserFunction}