should = require 'should'
TextLoader = require './TextLoader'
{Literal, InfixExpression} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'


describe 'TextLoader', ->

  loader = null
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)
  fn1 = new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
  fn2 = new UserFunction('fn2', [], new InfixExpression(' 22+10.5 ', '+', [aNumber22, aNumber]))

  beforeEach ->
    loader = new TextLoader()


  it 'returns definitions as text', ->
    loader._defs = [fn1, fn2]
    loader.asText().should.eql 'fn1 = 10.5 / 22;\nfn2 = 22+10.5;\n'


