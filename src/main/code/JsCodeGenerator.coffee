{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'

module.exports = class JsCodeGenerator

  asLiteral = (value) -> JSON.stringify value

  jsOperator = (op) -> if op == '<>' then '!=' else op

  asList = (items, delimiters) ->
    start = delimiters[0]
    sep = delimiters[1]
    end = delimiters[2]
    if items.length then start + items.join(sep) + end else ''

  constructor: (@expr, contextName, @transformFunctionNames = []) ->
    @functionCalls = []
    @contextPrefix = if contextName then contextName + '.' else ''
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

      when expr instanceof FunctionCall and expr.functionName == 'in' then '_in'

      when expr instanceof FunctionCall and @_isTransformFunction expr
        @functionCalls.push expr if expr not in @functionCalls
        fnName = @contextPrefix + expr.functionName
        arg1 = @_generate expr.children[0]
        arg2 = @_generateFunction expr.children[1]
        fnName + asList [arg1, arg2], '(,)'

      when expr instanceof FunctionCall
        @functionCalls.push expr if expr not in @functionCalls
        fnName = @contextPrefix + expr.functionName
        args = (@_generate(e) for e in expr.children)
        fnName + asList args, '(,)'


      when expr instanceof AggregationSelector
        aggCode = @_generate expr.aggregation
        "(#{aggCode}).#{expr.elementName}"

      else
        throw new Error("JsCodeGenerator: Unknown expression: " + expr?.constructor.name)

  _generateFunction: (expr) ->
    "function(_in) { return #{@_generate expr} }"

  _isTransformFunction: (functionCall) -> @transformFunctionNames.indexOf(functionCall.functionName) != -1
