class Expression
  constructor: (@text, @children = []) ->

class Literal extends Expression
  constructor: (text, @value) ->
    super text

class Sequence extends Expression
  constructor: (text, children) ->
    super text, children

class Aggregation extends Expression
  constructor: (text, @childMap) ->
    childExprs = (expr for name, expr of childMap)
    super text, childExprs

class FunctionCall extends Expression
  constructor: (text, @functionName, argumentList) ->
    super text, argumentList

module.exports = {Expression, Literal, Sequence, Aggregation, FunctionCall}
