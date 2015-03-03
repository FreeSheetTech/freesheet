{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'

module.exports = class JsCodeGenerator

  asLiteral = (value) -> JSON.stringify value

  constructor: (@expr) ->
    @functionCalls = []
    @code = @_generate expr

  _generate: (expr) ->
    switch
      when expr instanceof Literal
        asLiteral expr.value

      when expr instanceof InfixExpression
        left = @_generate(expr.children[0])
        right = @_generate(expr.children[1])
        "#{left} #{expr.operator} #{right}"

      when expr instanceof Aggregation
        items = []
        for i in [0...expr.children.length]
          items.push "#{expr.childNames[i]}: #{@_generate expr.children[i] }"

        '{' + items.join(', ') + '}'

      when expr instanceof Sequence
        items = (@_generate(e) for e in expr.children)
        '[' + items.join(', ') + ']'

      when expr instanceof FunctionCall
        @functionCalls.push expr if expr not in @functionCalls
        expr.functionName

      when expr instanceof AggregationSelector
        @_exprStream(expr.aggregation).map (x) -> el = expr.elementName; x?[el]

      else
        throw new Error("JsCodeGenerator: Unknown expression: " + expr.constructor.name)


