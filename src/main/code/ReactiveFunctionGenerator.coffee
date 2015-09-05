{Literal, InfixExpression, Aggregation, Sequence, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
Eval = require './ReactiveEvaluators'
FunctionTypes = require '../runtime/FunctionTypes'
_ = require 'lodash'

tracing = false
trace = (onOff) -> tracing = onOff

callArgList = (items) -> '(' + items.join(', ') + ')'

exprFunction = (funcDef, functionInfo, userFunctions, providedFunctions, getCurrentEvent, argumentManager) ->

  exprCode = (expr, functionInfo, argNames = [], incomingLocalNames = []) ->
    functionNames = []

    accumulateFunctionName = (name) -> functionNames.push name if name not in functionNames

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
        items = (getCodeAndAccumulateFunctions(e) for e in expr.children)
        new Eval.Aggregation expr, expr.childNames, items

      when expr instanceof Sequence
        items = (getCodeAndAccumulateFunctions(e) for e in expr.children)
        new Eval.Sequence expr, items

      when expr instanceof AggregationSelector
        agg = getCodeAndAccumulateFunctions expr.aggregation
        new Eval.AggregationSelector expr, agg, expr.elementName

      when expr instanceof FunctionCall and expr.functionName == 'in' then new Eval.ArgRef 'in'
      when expr instanceof FunctionCall and _.includes(argNames, expr.functionName) then new Eval.ArgRef expr.functionName

      when expr instanceof Input
        new Eval.Input expr, expr.inputName, getCurrentEvent

      when expr instanceof FunctionCall
        functionName = expr.functionName
        accumulateFunctionName functionName

        args =  if isTransformFunction expr
                  transformExpr = expr.children[1]
                  transformEval = getCodeAndAccumulateFunctions(transformExpr)
                  transformFunction = new Eval.ExpressionFunction transformEval
                  [getCodeAndAccumulateFunctions(expr.children[0]), transformFunction]
                else
                  (getCodeAndAccumulateFunctions(e) for e in expr.children)

        if args.length
          new Eval.FunctionCallWithArgs expr, functionName, args, userFunctions, providedFunctions
        else
          new Eval.FunctionCallNoArgs expr, functionName, userFunctions, providedFunctions

      else
        throw new Error("ReactiveFunctionGenerator: Unknown expression: " + expr?.constructor.name)

    {code: code, functionNames}

  {code, functionNames} = exprCode funcDef.expr, functionInfo, funcDef.argNames()
  {theFunction: code, functionNames}


module.exports = {exprFunction, trace}
