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
        Rx.Observable.combineLatest @_exprStreams(expr.children), aggregateFunction(expr.childNames)

      when expr instanceof Sequence
        Rx.Observable.combineLatest @_exprStreams(expr.children), sequenceFunction

      when expr instanceof FunctionCall
        name = expr.functionName
        switch
          when func = @userFunctions[name] then @_userFunctionSubject name
          when func = @providedFunctions[name] then @_providedFunctionStream func, expr.children
          else @_userFunctionSubject name

      when expr instanceof AggregationSelector
        @_exprStream(expr.aggregation).map (x) -> el = expr.elementName; x?[el]

      else
        throw new Error("JsCodeGenerator: Unknown expression: " + expr.constructor.name)


