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
  fn3 = new UserFunction('fn3', [], new InfixExpression('22 - 10.5', '-', [aNumber22, aNumber]))

  beforeEach ->
    runner =
      addUserFunction: sinon.spy()
      removeUserFunction: sinon.spy()
    loader = new TextLoader(runner)


  it 'returns definitions as text', ->
    loader._defs = [fn1, fn2]
    loader.asText().should.eql 'fn1 = 10.5 / 22;\nfn2 = 22+10.5;\n'

  it 'sets a function from a FunctionDefinition and puts it at the end', ->
    loader._defs = [fn1]
    loader.setFunction(fn2)
    loader.functionDefinitions().should.eql [fn1, fn2]
    runner.addUserFunction.should.have.been.calledWith(fn2)

  it 'sets a function from a FunctionDefinition and puts it at the end if beforeName not found', ->
    loader._defs = [fn1]
    loader.setFunction(fn2, 'xxx')
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

  it 'adds a function from a text definition and puts it before a given name', ->
    loader._defs = [fn1, fn3]
    loader.setFunctionAsText('fn2', ' 22+10.5 ', 'fn2', 'fn3')
    loader.functionDefinitions().should.eql [fn1, fn2, fn3]
    runner.removeUserFunction.should.not.have.been.calledWith('fn2')
    runner.addUserFunction.should.have.been.calledWith(fn2)

  it 'replaces a function from a text definition and puts it before a given name', ->
    loader._defs = [fn1, fn3]
    loader.setFunctionAsText('fn2', ' 22+10.5 ', 'fn1', 'fn3')
    loader.functionDefinitions().should.eql [fn2, fn3]
    runner.removeUserFunction.should.have.been.calledWith('fn1')
    runner.addUserFunction.should.have.been.calledWith(fn2)

  it 'removes a function by name', ->
    loader._defs = [fn1, fn2]
    loader.removeFunction 'fn1'
    loader.functionDefinitions().should.eql [fn2]
    runner.removeUserFunction.should.have.been.calledWith('fn1')
    runner.addUserFunction.should.not.have.been.called

