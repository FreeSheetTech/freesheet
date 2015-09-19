should = require 'should'
{UserFunction} = require './FunctionDefinition'

describe 'Function Definitions', ->

  it 'UserFunction stores types and expression', ->
    expr = 'an expr'
    argNames = ['a', 'bbb']
    fn = new UserFunction('fn1', argNames, expr)
    fn.name.should.eql 'fn1'
    fn.expr.should.equal expr
