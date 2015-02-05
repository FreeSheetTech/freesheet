class FunctionDefinition
  constructor: (@name, @argDefs, @returnKind) ->

class UserFunction extends FunctionDefinition
  constructor: (name, argDefs, returnKind, @expr) ->
    super name, argDefs, returnKind

class BuiltInFunction extends FunctionDefinition
  constructor: (name, argDefs, returnKind, @implementation) ->
    super name, argDefs, returnKind

class ArgumentDefinition
  constructor: (@name, @kind) ->

module.exports = {FunctionDefinition, UserFunction, BuiltInFunction, ArgumentDefinition}