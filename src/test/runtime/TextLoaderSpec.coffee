chai = require 'chai'
sinon = require 'sinon'
sinonChai = require 'sinon-chai'
TextLoader = require './TextLoader'
{Literal, InfixExpression} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'

should = chai.Should()
chai.use sinonChai


describe 'TextLoader', ->

  loader = null
  runner = null
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)
  fn1 = new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
  fn2 = new UserFunction('fn2', [], new InfixExpression('22+10.5', '+', [aNumber22, aNumber]))

  beforeEach ->
    runner =
      addUserFunction: sinon.spy()
      removeUserFunction: sinon.spy()
    loader = new TextLoader(runner)


  it 'returns definitions as text', ->
    loader._defs = [fn1, fn2]
    loader.asText().should.eql 'fn1 = 10.5 / 22;\nfn2 = 22+10.5;\n'

  it 'sets a function from a FunctionDefinition', ->
    loader._defs = [fn1]
    loader.setFunction(fn2)
    loader.functionDefinitions().should.eql [fn1, fn2]
    runner.addUserFunction.should.have.been.calledWith(fn2)

  it 'replaces a function from a FunctionDefinition', ->
    loader._defs = [fn1]
    loader.setFunction(fn2, 'fn1')
    loader.functionDefinitions().should.eql [fn2]
    runner.removeUserFunction.should.have.been.calledWith('fn1')
    runner.addUserFunction.should.have.been.calledWith(fn2)

  it 'replaces a function from a text definition', ->
    loader._defs = [fn1]
    loader.setFunctionAsText('fn2', ' 22+10.5 ', 'fn1')
    loader.functionDefinitions().should.eql [fn2]
    runner.removeUserFunction.should.have.been.calledWith('fn1')
    runner.addUserFunction.should.have.been.calledWith(fn2)


