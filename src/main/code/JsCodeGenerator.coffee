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

combineCode = (argNames, exprCode) ->
  args = argNames.join ', '
  "operations.combine(#{args}, function(#{args}) { return #{exprCode}; })"

localStreamsVars = (localStreams) -> if localStreams.length then ("var #{s.name} = #{s.code};" for s in localStreams).join('\n') + '\n' else ''

subjectCode = (exprCode) -> "operations.subject(#{exprCode})"

isStreamFunctionCall = (expr, functionInfo) -> expr instanceof FunctionCall and functionInfo[expr.functionName]?.kind == 'stream'
isNoArgsFunctionCall = (expr) -> expr instanceof FunctionCall and expr.children.length == 0

streamCode = (expr, functionInfo, code, combineNames) ->
  if isStreamFunctionCall(expr, functionInfo)
    code
  else if isNoArgsFunctionCall(expr)
    code
  else if combineNames.length
     combineCode(combineNames, code)
  else
    subjectCode(code)

exprFunctionBody = (expr, functionInfo) ->
  {code, functionNames, localStreams, combineNames} = exprCode expr, functionInfo
  varDecls = localStreamsVars(localStreams)
  codeForStreams = streamCode(expr, functionInfo, code, combineNames)
  bodyCode = "#{varDecls}return #{codeForStreams};"

  {code: bodyCode, functionNames}

exprCode = (expr, functionInfo) ->
  functionNames = []
  localStreams = []
  combineNames = []

  accumulateFunctionName = (name) -> functionNames.push name if name not in functionNames
  accumulateLocalStream = (name, code) -> localStreams.unshift {name, code}
  accumulateFunctionNames = (names) -> accumulateFunctionName(n) for n in names
  accumulateLocalStreams = (streams) -> localStreams.unshift s for s in streams
  accumulateCombineName = (name) -> combineNames.push name
  accumulateCombineNames = (names) -> combineNames = combineNames.concat names

  generateFunction = (expr) -> "function(_in) { return #{getCodeAndAccumulateFunctions expr} }"

  isTransformFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'transform'
  isStreamFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'stream'

  getCodeAndAccumulateFunctions = (expr) ->
    exprResult = exprCode expr, functionInfo
    accumulateFunctionNames exprResult.functionNames
    accumulateCombineNames exprResult.combineNames
    accumulateLocalStreams exprResult.localStreams
    exprResult.code

  localStreamCode = (expr, code, combineNames) ->
    if isNoArgsFunctionCall(expr)
      code
    else if combineNames.length
      combineCode(combineNames, code)
    else
      subjectCode(code)

  getStreamCodeAndAccumulateFunctions = (expr) ->
    exprResult = exprCode expr, functionInfo
    accumulateFunctionNames exprResult.functionNames
    accumulateLocalStreams exprResult.localStreams
    localStreamCode expr, exprResult.code, exprResult.combineNames

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

    when expr instanceof AggregationSelector
      aggCode = getCodeAndAccumulateFunctions expr.aggregation
      "(#{aggCode}).#{expr.elementName}"

    when expr instanceof FunctionCall and expr.functionName == 'in' then '_in'

    when expr instanceof FunctionCall and isTransformFunction expr
      functionName = expr.functionName
      accumulateFunctionName functionName
      accumulateCombineName functionName
      arg1 = getCodeAndAccumulateFunctions expr.children[0]
      arg2 = generateFunction expr.children[1]
      functionName + argList [arg1, arg2]

    when expr instanceof FunctionCall and isStreamFunction expr
      functionName = expr.functionName
      accumulateFunctionName functionName
      args = (getStreamCodeAndAccumulateFunctions(e) for e in expr.children)
      lsCode = functionName + argList args
      lsName = functionName + "_1"
      accumulateLocalStream lsName, lsCode
      accumulateCombineName lsName
      lsName

#      [ 'addFive', 'total', 'b' ]
#      Expected :"var total_1 = total(b);\nreturn operations.combine(addFive, total_1, function(addFive, total_1) { return addFive(total_1); });"
#      Actual   :"var total_1 = total(b);\nreturn operations.combine(addFive, total, b, function(addFive, total, b) { return addFive(total_1); });"
#
#      For stream function, we need to:
#         - accumulate function name of function itself up to top level
#         - accumulate function names of functions used in arguments up to top level
#         - create a local stream name
#         - create a local stream expr - combine names of this expr and arguments if multiple inputs
#         - accumulate the local stream up to top level
#         - use the local stream name as the expr
#         - Use the local stream name in the combine at the next level
#         - Use the function names from this expr and arguments in the combine of the local stream expr
#         - Do not pass the function names from this expr or arguments to the combine at the next level
#
#
#

    when expr instanceof FunctionCall
      functionName = expr.functionName
      accumulateFunctionName functionName
      accumulateCombineName functionName
      args = (getCodeAndAccumulateFunctions(e) for e in expr.children)
      functionName + argList args

    else
      throw new Error("JsCodeGenerator: Unknown expression: " + expr?.constructor.name)

  {code, functionNames, localStreams, combineNames}


module.exports = {exprCode, exprFunctionBody, exprFunction}