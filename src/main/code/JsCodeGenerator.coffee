{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'

#TODO sort out mix of functions and statefulness in this class around collecting the function names
module.exports = class JsCodeGenerator

  asLiteral = (value) -> JSON.stringify value

  jsOperator = (op) -> if op == '<>' then '!=' else op

  argList = (items) -> if items.length then '(' + items.join(', ') + ')' else ''

  createFunction = (argNames, functionBody) ->
    functionCreateArgs = [null].concat 'operations', argNames, functionBody
    new (Function.bind.apply(Function, functionCreateArgs));


  constructor: (@expr, contextName, @transformFunctionNames = []) ->
    @functionNames = []
    @contextPrefix = if contextName then contextName + '.' else ''
    @code = @_generate @expr  # also collect function names

  exprFunction: -> createFunction(@functionNames, @exprFunctionBody())

  exprFunctionBody: -> @_generateStream @expr

  exprCode: -> @code

  _generateStream: (expr) ->
    args = @functionNames.join ', '
    streamCode = if args
        combineFunctionCode = "function(#{args}) { return #{@exprCode()}; }"
        "operations.combine(#{args}, #{combineFunctionCode})"
      else
        "operations.subject(#{@exprCode()})"

    "return #{streamCode};"

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
        functionName = expr.functionName
        @functionNames.push functionName if functionName not in @functionNames
        fnName = @contextPrefix + functionName
        arg1 = @_generate expr.children[0]
        arg2 = @_generateFunction expr.children[1]
        fnName + argList [arg1, arg2]

      when expr instanceof FunctionCall
        functionName = expr.functionName
        @functionNames.push functionName if functionName not in @functionNames
        fnName = @contextPrefix + functionName
        args = (@_generate(e) for e in expr.children)
        fnName + argList args


      when expr instanceof AggregationSelector
        aggCode = @_generate expr.aggregation
        "(#{aggCode}).#{expr.elementName}"

      else
        throw new Error("JsCodeGenerator: Unknown expression: " + expr?.constructor.name)

  _generateFunction: (expr) ->
    "function(_in) { return #{@_generate expr} }"

  _isTransformFunction: (functionCall) -> @transformFunctionNames.indexOf(functionCall.functionName) != -1
