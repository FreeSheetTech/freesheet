class FunctionDefinition
  constructor: (@name, @argDefs, @returnKind) ->

class UserFunction extends FunctionDefinition
  constructor: (name, argNames, @expr) ->
    super name, streamArgDefs(argNames), 'stream'

class BuiltInFunction extends FunctionDefinition
  constructor: (name, argDefs, returnKind, @implementation) ->
    super name, argDefs, returnKind

class ArgumentDefinition
  constructor: (@name, @kind) ->

class FunctionError
  constructor: (@name, text, @error) ->
    @expr = {text}


streamArgDefs = (names) -> (new ArgumentDefinition(n, 'stream') for n in names)

module.exports = {FunctionDefinition, UserFunction, BuiltInFunction, ArgumentDefinition, FunctionError}