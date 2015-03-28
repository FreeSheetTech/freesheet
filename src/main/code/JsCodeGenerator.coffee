{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector} = require '../ast/Expressions'

asLiteral = (value) -> JSON.stringify value

jsOperator = (op) -> if op == '<>' then '!=' else op

argList = (items) -> if items.length then '(' + items.join(', ') + ')' else ''

createFunction = (argNames, functionBody) ->
  functionCreateArgs = [null].concat 'operations', argNames, functionBody
  new (Function.bind.apply(Function, functionCreateArgs));

exprFunction = (expr, functionInfo) ->
  {code, functionNames} = exprFunctionBody expr, functionInfo
  theFunction = createFunction functionNames, code
  {theFunction, functionNames}

exprFunctionBody = (expr, functionInfo) ->
  {code, functionNames} = exprCode expr, functionInfo
  args = functionNames.join ', '
  streamCode = if args
    combineFunctionCode = "function(#{args}) { return #{code}; }"
    "operations.combine(#{args}, #{combineFunctionCode})"
  else
    "operations.subject(#{code})"

  {code: "return #{streamCode};", functionNames}

exprCode = (expr, functionInfo) ->
  functionNames = []

  accumulateFunctionName = (name) -> functionNames.push name if name not in functionNames
  accumulateFunctionNames = (names) -> accumulateFunctionName(n) for n in names

  generateFunction = (expr) -> "function(_in) { return #{getCodeAndAccumulateFunctions expr} }"

  isTransformFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'transform'

  getCodeAndAccumulateFunctions = (expr) ->
    exprResult = exprCode expr, functionInfo
    accumulateFunctionNames exprResult.functionNames
    exprResult.code

  code = switch
    when expr instanceof Literal
      asLiteral expr.value

    when expr instanceof InfixExpression
      left = getCodeAndAccumulateFunctions expr.children[0]
      right = getCodeAndAccumulateFunctions expr.children[1]
      switch expr.operator
        when '+' then "operations.add(#{left}, #{right})"
        when '-' then "operations.subtract(#{left}, #{right})"
        else "(#{left} #{jsOperator(expr.operator)} #{right})"

    when expr instanceof Aggregation
      items = []
      for i in [0...expr.children.length]
        items.push "#{expr.childNames[i]}: #{getCodeAndAccumulateFunctions expr.children[i] }"

      '{' + items.join(', ') + '}'

    when expr instanceof Sequence
      items = (getCodeAndAccumulateFunctions(e) for e in expr.children)
      '[' + items.join(', ') + ']'

    when expr instanceof FunctionCall and expr.functionName == 'in' then '_in'

    when expr instanceof FunctionCall and isTransformFunction expr
      functionName = expr.functionName
      accumulateFunctionName functionName
      arg1 = getCodeAndAccumulateFunctions expr.children[0]
      arg2 = generateFunction expr.children[1]
      functionName + argList [arg1, arg2]

    when expr instanceof FunctionCall
      functionName = expr.functionName
      accumulateFunctionName functionName
      args = (getCodeAndAccumulateFunctions(e) for e in expr.children)
      functionName + argList args

    when expr instanceof AggregationSelector
      aggCode = getCodeAndAccumulateFunctions expr.aggregation
      "(#{aggCode}).#{expr.elementName}"

    else
      throw new Error("JsCodeGenerator: Unknown expression: " + expr?.constructor.name)

  {code, functionNames}


module.exports = {exprCode, exprFunctionBody, exprFunction}