should = require 'should'
{BuiltInFunction, UserFunction, ArgumentDefinition} = require './FunctionDefinition'

describe 'Function Definitions', ->

  it 'BuiltInFunction stores types and implementation', ->
    fnImpl = ()-> 'the answer'
    argList = ['x', 10]
    fn = new BuiltInFunction('fn1', argList, 'stream', fnImpl)
    fn.name.should.eql 'fn1'
    fn.argDefs.should.eql argList
    fn.returnKind.should.eql 'stream'
    fn.implementation.should.equal fnImpl

  it 'UserFunction stores types and expression', ->
    expr = 'an expr'
    argNames = ['a', 'bbb']
    fn = new UserFunction('fn1', argNames, expr)
    fn.name.should.eql 'fn1'
    fn.argDefs.should.eql [new ArgumentDefinition('a', 'stream'), new ArgumentDefinition('bbb', 'stream')]
    fn.returnKind.should.eql 'stream'
    fn.expr.should.equal expr
