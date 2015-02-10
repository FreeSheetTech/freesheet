Rx = require 'rx'
{Literal, InfixExpression, FunctionCall} = require '../ast/Expressions'

class ReactiveRunner
  constructor: (@builtInFunctions, @userFunctions) ->

  output: (name) ->
    func = @userFunctions[name]
    stream = @_instantiateFunctionStream func
    stream


#  private functions

  _instantiateFunctionStream: (func) ->
    @_instantiateExprStream func.expr

  _instantiateExprStream: (expr) ->
    switch
      when expr instanceof Literal
        new Rx.BehaviorSubject(expr.value)
      when expr instanceof InfixExpression
        leftObs = @_instantiateExprStream expr.children[0]
        rightObs = @_instantiateExprStream expr.children[1]
        Rx.Observable.combineLatest leftObs, rightObs, @_infixOperatorFunction(expr.operator)

      when expr instanceof FunctionCall
        func = @userFunctions[expr.functionName]
        @_instantiateFunctionStream func

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _infixOperatorFunction: (operator) ->
    switch operator
      when '+' then (a, b) -> a + b
      when '/' then (a, b) -> a / b
      else throw new Error("Unknown operator: " + operator)

module.exports = {ReactiveRunner}