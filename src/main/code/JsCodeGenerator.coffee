{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'

module.exports = class JsCodeGenerator

  asLiteral = (value) -> JSON.stringify value

  jsOperator = (op) -> if op == '<>' then '!=' else op

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
        switch expr.operator
          when '+' then "operations.add(#{left}, #{right})"
          when '-' then "operations.subtract(#{left}, #{right})"
          else "(#{left} #{jsOperator(expr.operator)} #{right})"

      when expr instanceof Aggregation
        items = []
        for i in [0...expr.children.length]
          items.push "#{expr.childNames[i]}: #{@_generate expr.children[i] }"

        '{' + items.join(', ') + '}'

      when expr instanceof Sequence
        items = (@_generate(e) for e in expr.children)
        '[' + items.join(', ') + ']'

      when expr instanceof FunctionCall
        name = expr.functionName
        if name == 'in'
          '_in'
        else
          @functionCalls.push expr if expr not in @functionCalls
          expr.functionName

      when expr instanceof AggregationSelector
        aggCode = @_generate expr.aggregation
        "(#{aggCode}).#{expr.elementName}"

      else
        throw new Error("JsCodeGenerator: Unknown expression: " + expr.constructor.name)


