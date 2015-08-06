{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
FunctionTypes = require '../runtime/FunctionTypes'
_ = require 'lodash'

tracing = false
trace = (onOff) -> tracing = onOff

asLiteral = (value) ->
  values = [value]
  newValues: -> values
  latestValue: -> value
  reset: -> values = []

NotCalculated = 'NOT_CALCULATED'

class Add
  constructor: (@funcdef, @left, @right) ->
    @values = NotCalculated
    @latest = NotCalculated

  newValues: ->
    if @values is NotCalculated
      leftValues = @left.newValues()
      rightValues = @right.newValues()
      if leftValues.length or rightValues.length
        @values = [@left.latestValue() + @right.latestValue()]
        @latest = NotCalculated
    @values

  latestValue: ->
    @newValues() #ensure use any new values
    if @latest is NotCalculated
      @latest = [@left.latestValue() + @right.latestValue()]
    @latest

  reset: -> @values = NotCalculated

jsOperator = (op) ->
  switch op
    when '<>' then '!='
    when 'and' then '&&'
    when 'or' then '||'
    else op

callArgList = (items) -> '(' + items.join(', ') + ')'

exprFunction = (funcDef, functionInfo) ->
  {code, functionNames} = exprCode funcDef.expr, functionInfo, funcDef.argNames()
  {theFunction: code, functionNames}

exprCode = (expr, functionInfo, argNames = [], incomingLocalNames = []) ->
  functionNames = []

  fromContext = (name, args) ->
    switch
      when _.includes(incomingLocalNames, name) then "#{name}"
      else "this.#{name}#{callArgList(args)}"

  accumulateFunctionName = (name) -> functionNames.push name if name not in functionNames

  applyTransformFunction = (expr) -> "function(_in) { return #{getCodeAndAccumulateFunctions expr} }.bind(this)"

  isTransformFunction = (functionCall) -> functionInfo[functionCall.functionName]?.kind == FunctionTypes.TRANSFORM

  getCodeAndAccumulateFunctions = (expr, localNames) ->
    allLocalNames = incomingLocalNames[..].concat localNames
    exprResult = exprCode expr, functionInfo, argNames, allLocalNames
    accumulateFunctionName(n) for n in _.difference exprResult.functionNames, allLocalNames
    exprResult.code

  code = switch
    when expr instanceof Literal
      asLiteral expr.value

    when expr instanceof InfixExpression
      left = getCodeAndAccumulateFunctions expr.children[0]
      right = getCodeAndAccumulateFunctions expr.children[1]
      switch expr.operator
        when '+' then new Add(expr, left, right)
        when '-' then "this.operations.subtract(#{left}, #{right})"
        else "(#{left} #{jsOperator(expr.operator)} #{right})"

    when expr instanceof Aggregation
      varDecls = []
      items = []
      aggregationNames = (n for n in expr.childNames)

      for i in [0...expr.children.length]
        name = expr.childNames[i]
        varDecls.push "#{name} = #{getCodeAndAccumulateFunctions expr.children[i], aggregationNames }"
        items.push "#{name}: #{name}"

      "function() { var #{varDecls.join(',\n    ')};\nreturn {#{items.join(', ')}}; }.bind(this)()"

    when expr instanceof Sequence
      items = (getCodeAndAccumulateFunctions(e) for e in expr.children)
      '[' + items.join(', ') + ']'

    when expr instanceof AggregationSelector
      aggCode = getCodeAndAccumulateFunctions expr.aggregation
      "(#{aggCode}).#{expr.elementName}"

    when expr instanceof FunctionCall and expr.functionName == 'in' then '_in'
    when expr instanceof FunctionCall and _.includes(argNames, expr.functionName) then expr.functionName

    when expr instanceof Input
      "null"

    when expr instanceof FunctionCall
      functionName = expr.functionName
      accumulateFunctionName functionName

      args =  if isTransformFunction expr
                [getCodeAndAccumulateFunctions(expr.children[0]), applyTransformFunction(expr.children[1])]
              else
                (getCodeAndAccumulateFunctions(e) for e in expr.children)

      callCode = fromContext(functionName, args)

      if tracing then "operations.trace('#{functionName}', #{callCode})" else callCode

    else
      throw new Error("FunctionObjectGenerator: Unknown expression: " + expr?.constructor.name)

  {code: code, functionNames}


module.exports = {exprCode, exprFunction, trace}
