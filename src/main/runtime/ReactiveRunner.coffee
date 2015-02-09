Rx = require 'rx'
{Literal} = require '../ast/Expressions'

class ReactiveRunner
  constructor: (@builtInFunctions, @userFunctions) ->

  output: (name) ->
    func = @userFunctions[name]
    stream = @_instantiateStream func
    stream


#  private functions

  _instantiateStream: (func) ->
    expr = func.expr
    if expr instanceof Literal
      new Rx.BehaviorSubject(expr.value)


module.exports = {ReactiveRunner}