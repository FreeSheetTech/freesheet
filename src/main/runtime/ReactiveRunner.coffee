Rx = require 'rx'
{Literal, InfixExpression, FunctionCall} = require '../ast/Expressions'

class ReactiveRunner
  constructor: (@providedFunctions, @userFunctions) ->

  output: (name) ->
    func = @userFunctions[name]
    stream = @_instantiateUserFunctionStream func
    stream


#  private functions

  _instantiateUserFunctionStream: (func) ->
    @_instantiateExprStream func.expr

  _instantiateProvidedFunctionStream: (func) ->
    result = func.call null, []
    result

  _instantiateExprStream: (expr) ->
    switch
      when expr instanceof Literal
        new Rx.BehaviorSubject(expr.value)
      when expr instanceof InfixExpression
        leftObs = @_instantiateExprStream expr.children[0]
        rightObs = @_instantiateExprStream expr.children[1]
        Rx.Observable.combineLatest leftObs, rightObs, @_infixOperatorFunction(expr.operator)

      when expr instanceof FunctionCall
        name = expr.functionName
        switch
          when func = @userFunctions[name] then @_instantiateUserFunctionStream func
          when provided = @providedFunctions[name] then @_instantiateProvidedFunctionStream provided
          else throw new Error "Unknown function: " + name

      else
        throw new Error("Unknown expression: " + expr.constructor.name)

  _infixOperatorFunction: (operator) ->
    switch operator
      when '+' then (a, b) -> a + b
      when '-' then (a, b) -> a - b
      when '/' then (a, b) -> a / b
      else throw new Error("Unknown operator: " + operator)

module.exports = {ReactiveRunner}