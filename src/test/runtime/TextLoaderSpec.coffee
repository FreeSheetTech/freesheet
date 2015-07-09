chai = require 'chai'
sinon = require 'sinon'
sinonChai = require 'sinon-chai'
TextLoader = require './TextLoader'
{Literal, InfixExpression} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'
{FunctionError} = require '../error/Errors'

should = chai.Should()
chai.use sinonChai


describe 'TextLoader', ->

  loader = null
  runner = null
  changeCallback = null
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)
  fn1 = new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
  fn2 = new UserFunction('fn2', [], new InfixExpression('22+10.5', '+', [aNumber22, aNumber]))
  fn3 = new UserFunction('fn3', [], new InfixExpression('22 - 10.5', '-', [aNumber22, aNumber]))
  fnArgs = new UserFunction('fnArgs', ['xx', 'a'], new InfixExpression('22 - 10.5', '-', [aNumber22, aNumber]))

  beforeEach ->
    runner =
      addUserFunction: sinon.spy()
      removeUserFunction: sinon.spy()
      onValueChange: (fn) -> changeCallback = fn
    loader = new TextLoader(runner)


  it 'returns definitions as text', ->
    loader._defs = [fn1, fn2]
    loader.asText().should.eql 'fn1 = 10.5 / 22;\nfn2 = 22+10.5;\n'

  it 'gets a definition by name', ->
    loader._defs = [fn1, fn2]
    loader.getFunction('fn2').should.eql fn2

  it 'gets text of a definition by name', ->
    loader._defs = [fn1, fn2]
    loader.getFunctionAsText('fn2').should.eql '22+10.5'

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
    newFn = loader.setFunctionAsText('fn2', ' 22+10.5 ', 'fn1')
    loader.functionDefinitions().should.eql [fn2]
    loader.functionDefinitions()[0].should.equal newFn
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

  it 'loads all definitions from text and adds them to those already there', ->
    loader._defs = [fn3]
    loader.loadDefinitions '   fn1 = 10.5 / 22;\n\n\nfn2 = 22+10.5;\n'
    loader.functionDefinitions().should.eql [fn3, fn1, fn2]

  it 'gets definitions with values in order', ->
    loader._defs = [fn3, fn1, fn2]
    changeCallback 'fn3', 10
    changeCallback 'fn2', 'ABC'
    loader.functionDefinitionsAndValues().should.eql [
      {name: 'fn3', definition: fn3, value: 10}
      {name: 'fn1', definition: fn1, value: null}
      {name: 'fn2', definition: fn2, value: 'ABC'}
    ]

  it 'updates values with changes', ->
    loader._defs = [fn3, fn2]
    loader._defs = [fn3, fn2]
    changeCallback 'fn3', 10
    changeCallback 'fn3', 'ABC'
    loader.functionDefinitionsAndValues().should.eql [
      {name: 'fn3', definition: fn3, value: 'ABC'}
      {name: 'fn2', definition: fn2, value: null}
    ]

  it 'sets a function and adds it to definitions and values before runner onValueChange triggered', ->
    runner.addUserFunction = (fn) ->
      changeCallback fn.name, 99
      loader.functionDefinitions().should.eql [fn2]
      loader.functionDefinitionsAndValues().should.eql [
        {name: 'fn2', definition: fn2, value: 99}
      ]

    loader._defs = []
    loader.setFunctionAsText('fn2', ' 22+10.5 ', 'fn2', 'fn3')

  it 'sets a function with a syntax error and notifies change but does not update runner', ->
    loader._defs = [fn1, fn3]
    fnErr = loader.setFunctionAsText('fn2', ' 22+ ', '', 'fn3')
    loader.functionDefinitions()[0].should.eql fn1
    loader.functionDefinitions()[1].name.should.eql 'fn2'
    loader.functionDefinitions()[1].error.toString().should.match /^SyntaxError.*/
    loader.functionDefinitions()[1].should.equal fnErr
    loader.functionDefinitions()[2].should.eql fn3
    loader.
    runner.removeUserFunction.should.have.been.calledWith('fn2')
    runner.addUserFunction.should.not.have.been.called

  it 'sets a function with a syntax error and keeps the text for all purposes', ->
    loader._defs = [fn1]
    loader.setFunctionAsText('fn2', ' 22+ ', '', '')
    loader.asText().should.eql '''fn1 = 10.5 / 22;\nfn2 = 22+;\n'''
    loader.getFunctionAsText('fn2').should.eql '22+'
    defsAndValues = loader.functionDefinitionsAndValues()
    defsAndValues[0].should.eql {name: 'fn1', definition: fn1, value: null}
    defsAndValues[1].name.should.eql 'fn2'
    defsAndValues[1].definition.name.should.eql 'fn2'
    defsAndValues[1].value.should.be.an.instanceof(Error)
    defsAndValues[1].value.toString().should.match /^SyntaxError.*/

  it 'loads definitions with errors from text and adds them to those already there', ->
    loader._defs = [fn3]
    loader.loadDefinitions '   fn1 = }+/;\n\n\nfn2 = 22+10.5;\n'
    loader.functionDefinitions()[0].should.eql fn3
    loader.functionDefinitions()[2].should.eql fn2
    loader.functionDefinitions()[1].name.should.eql 'fn1'
    loader.functionDefinitions()[1].error.toString().should.match /^SyntaxError.*/

    runner.removeUserFunction.should.have.been.calledWith('fn1')
    runner.addUserFunction.should.not.have.been.calledWith(fn1)
    runner.addUserFunction.should.have.been.calledWith(fn2)

  describe 'functions with arguments', ->
    it 'returns definitions as text', ->
      loader._defs = [fn1, fnArgs]
      loader.asText().should.eql 'fn1 = 10.5 / 22;\nfnArgs(xx, a) = 22 - 10.5;\n'

    it 'gets a definition by name', ->
      loader._defs = [fn1, fnArgs]
      loader.getFunction('fnArgs').should.eql fnArgs

    it 'gets text of a definition by name', ->
      loader._defs = [fn1, fnArgs]
      loader.getFunctionAsText('fnArgs').should.eql '22 - 10.5'

