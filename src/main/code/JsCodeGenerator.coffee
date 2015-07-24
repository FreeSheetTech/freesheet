{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
_ = require 'lodash'

class Name
  constructor: (@name, @local = false) ->
  toString: -> @name

tracing = false
trace = (onOff) -> tracing = onOff

asLiteral = (value) -> JSON.stringify value

jsOperator = (op) ->
  switch op
    when '<>' then '!='
    when 'and' then '&&'
    when 'or' then '||'
    else op

argList = (items) -> if items.length then '(' + items.join(', ') + ')' else ''

createFunction = (functionBody) ->
  functionCreateArgs = [null].concat 'operations','_ctx', functionBody
#  console.log 'functionBody', functionBody
  result = new (Function.bind.apply(Function, functionCreateArgs))
#  console.log 'createFunction', result
  result

# returns a function that when called with the context gives an Observable for use by the runner
exprFunction = (funcDef, functionInfo) ->
  {code, functionNames} = exprFunctionBody funcDef, functionInfo
  theFunction = createFunction code
  {theFunction, functionNames}

combineCode = (argNames, exprCode) ->
  names = (n.name for n in argNames)
  args = names.join ', '
  "operations.combine(#{fromContextAll(argNames).join ', '}, function(#{args}) { return #{exprCode}; })"

localStreamsVars = (localStreams) -> if localStreams.length then ("var #{s.name} = #{s.code};" for s in localStreams).join('\n') + '\n' else ''

subjectCode = (exprCode) -> "operations.subject(#{exprCode})"
functionCode = (exprCode, argNames) ->  "function#{argList(argNames)} { return #{exprCode}; }"
functionOrExprCode = (exprCode, argNames) -> if argNames.length == 0 then exprCode else functionCode exprCode, argNames

isStreamFunctionCall = (expr, functionInfo) -> expr instanceof FunctionCall and functionInfo[expr.functionName]?.kind == 'stream'
isNoArgsFunctionCall = (expr) -> expr instanceof FunctionCall and expr.children.length == 0
isFunctionCallWithArgs = (expr) -> expr instanceof FunctionCall and expr.children.length > 0
isInput = (expr) -> expr instanceof Input

fromContext = (name) ->
  switch
    when name instanceof Name and !name.local then "_ctx.#{name.name}"
    when name instanceof Name and name.local then name.name
    else "_ctx.#{name}"

fromContextAll = (names) -> (fromContext n for n in names)
withoutContext = (code) -> code.replace /_ctx./g, ''

streamCode = (expr, functionInfo, code, combineNames, argNames) ->
  if isStreamFunctionCall(expr, functionInfo)
    withoutContext(functionOrExprCode(code, argNames))
  else if isNoArgsFunctionCall(expr) and combineNames.length == 0
      code
  else if isInput(expr)
    code
  else if combineNames.length
     combineCode(combineNames, withoutContext(functionOrExprCode(code, argNames)))
  else
    subjectCode(functionOrExprCode(code, argNames))

exprFunctionBody = (funcDef, functionInfo) ->
  argNames = (ad.name for ad in funcDef.argDefs)
  {code, functionNames, localStreams, combineNames} = exprCode funcDef.expr, functionInfo, argNames
  varDecls = localStreamsVars(localStreams)
  codeForStreams = streamCode funcDef.expr, functionInfo, code, combineNames, argNames
  bodyCode = "#{varDecls}return #{codeForStreams};"

  {code: bodyCode, functionNames}

exprCode = (expr, functionInfo, argNames = [], incomingLocalNames = []) ->
  functionNames = []
  localStreams = []
  combineNames = []

  localStreamName = (name) ->
    startsWithName = (ls) -> ls.name.indexOf(name + '_') == 0
    existingStreamsCount = localStreams.filter(startsWithName).length
    name + '_' + (existingStreamsCount + 1)

  accumulateFunctionName = (name) -> functionNames.push name if name not in functionNames
  accumulateFunctionNames = (names) -> accumulateFunctionName(n) for n in names
  accumulateLocalStream = (name, code) -> localStreams.unshift {name, code}
  accumulateLocalStreams = (streams) -> localStreams.unshift s for s in streams
  accumulateCombineName = (name) ->
    if not _.find(combineNames, (n) -> n.name == name.name)
      combineNames.push name
  accumulateCombineNames = (names) -> accumulateCombineName(n) for n in names

  applyTransformFunction = (expr) -> "function(_in) { return #{getCodeAndAccumulateFunctions expr} }"

  isTransformFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'transform'
  isStreamFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'stream'
  isTransformStreamFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == 'transformStream'
  isStreamReturnFunction = (functionCall) -> functionInfo[functionCall.functionName]?.returnKind == 'streamReturn'
  returnsStream = (functionCall) -> isStreamFunction(functionCall) or isTransformStreamFunction(functionCall) or isStreamReturnFunction(functionCall)

  getCodeAndAccumulateFunctions = (expr, localNames) ->
    allLocalNames = incomingLocalNames[..].concat localNames
    exprResult = exprCode expr, functionInfo, argNames, allLocalNames
    accumulateFunctionName(n) for n in _.difference exprResult.functionNames, allLocalNames
    accumulateCombineName(n) for n in _.filter exprResult.combineNames, (n) -> not _.contains allLocalNames, n.name
    accumulateLocalStreams exprResult.localStreams
    exprResult.code

  localStreamCode = (expr, code, combineNames) ->
    if isNoArgsFunctionCall(expr)
      code
    else if combineNames.length
      combineCode(combineNames, withoutContext(code))
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
      varDecls = []
      items = []
      aggregationNames = (n for n in expr.childNames)

      for i in [0...expr.children.length]
        name = expr.childNames[i]
        varDecls.push "#{name} = #{getCodeAndAccumulateFunctions expr.children[i], aggregationNames }"
        items.push "#{name}: #{name}"

      "function() { var #{varDecls.join(',\n    ')};\nreturn {#{items.join(', ')}}; }()"

    when expr instanceof Sequence
      items = (getCodeAndAccumulateFunctions(e) for e in expr.children)
      '[' + items.join(', ') + ']'

    when expr instanceof AggregationSelector
      aggCode = getCodeAndAccumulateFunctions expr.aggregation
      "(#{aggCode}).#{expr.elementName}"

    when expr instanceof FunctionCall and expr.functionName == 'in' then '_in'
    when expr instanceof FunctionCall and _.includes(argNames, expr.functionName) then expr.functionName

    when expr instanceof Input
      "operations.input(\"#{expr.inputName}\")"

    when expr instanceof FunctionCall
      functionName = expr.functionName
      accumulateFunctionName functionName

      callCode = if returnsStream expr
        args =  switch
          when isStreamFunction expr then (getStreamCodeAndAccumulateFunctions(e) for e in expr.children)
          when isTransformStreamFunction expr then [getStreamCodeAndAccumulateFunctions(expr.children[0]), applyTransformFunction(expr.children[1])]
          when isStreamReturnFunction expr then (getCodeAndAccumulateFunctions(e) for e in expr.children)

        lsCode = fromContext functionName + argList args
        lsName = localStreamName functionName
        accumulateLocalStream lsName, lsCode
        accumulateCombineName new Name lsName, true
        fromContext lsName

      else
        accumulateCombineName new Name functionName
        args =
            if isTransformFunction expr
                [getCodeAndAccumulateFunctions(expr.children[0]), applyTransformFunction(expr.children[1])]
            else
                (getCodeAndAccumulateFunctions(e) for e in expr.children)

        if args.length
          "operations.eval(#{fromContext(functionName)})#{argList args}"
        else
          fromContext(functionName)

      if tracing then "operations.trace('#{functionName}', #{callCode})" else callCode

    else
      throw new Error("JsCodeGenerator: Unknown expression: " + expr?.constructor.name)

  {code: code, functionNames, localStreams, combineNames}


module.exports = {exprCode, exprFunctionBody, exprFunction, trace}
