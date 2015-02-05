should = require 'should'
{BuiltInFunction, UserFunction} = require './FunctionDefinition'

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
    argList = ['x', 10]
    fn = new UserFunction('fn1', argList, 'value', expr)
    fn.name.should.eql 'fn1'
    fn.argDefs.should.eql argList
    fn.returnKind.should.eql 'value'
    fn.expr.should.equal expr
