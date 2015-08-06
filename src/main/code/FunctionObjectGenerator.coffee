{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
Eval = require './ExpressionEvaluators'
FunctionTypes = require '../runtime/FunctionTypes'
_ = require 'lodash'

tracing = false
trace = (onOff) -> tracing = onOff

callArgList = (items) -> '(' + items.join(', ') + ')'

exprFunction = (funcDef, functionInfo, sheet) ->

  exprCode = (expr, functionInfo, argNames = [], incomingLocalNames = []) ->
    functionNames = []

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
        new Eval.Literal expr, expr.value

      when expr instanceof InfixExpression
        left = getCodeAndAccumulateFunctions expr.children[0]
        right = getCodeAndAccumulateFunctions expr.children[1]
        switch expr.operator
          when '+' then new Eval.Add expr, left, right
          when '-' then new Eval.Subtract expr, left, right
          when '*' then new Eval.Multiply expr, left, right
          when '/' then new Eval.Divide expr, left, right
          when '==' then new Eval.Eq expr, left, right
          when '<>' then new Eval.NotEq expr, left, right
          when '>' then new Eval.Gt expr, left, right
          when '<' then new Eval.Lt expr, left, right
          when '>=' then new Eval.GtEq expr, left, right
          when '<=' then new Eval.LtEq expr, left, right
          when 'and' then new Eval.And expr, left, right
          when 'or' then new Eval.Or expr, left, right
          else throw new Error "Unknown operator: #{expr.operator}"

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

        new Eval.FunctionCallNoArgs expr, functionName, sheet

      else
        throw new Error("FunctionObjectGenerator: Unknown expression: " + expr?.constructor.name)

    {code: code, functionNames}

  {code, functionNames} = exprCode funcDef.expr, functionInfo, funcDef.argNames()
  {theFunction: code, functionNames}


module.exports = {exprFunction, trace}
