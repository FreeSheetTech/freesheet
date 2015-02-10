should = require 'should'
{TextParser} = require './TextParser'
{Literal, Sequence, Aggregation, FunctionCall} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'


describe 'TextParser parses', ->

  expressionFor = (text) -> new TextParser(text).expression()
  functionFor = (text) -> new TextParser(text).functionDefinition()
  functionMapFor = (text) -> new TextParser(text).functionDefinitionMap()
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)

  describe 'expressions', ->

    it 'string to a Literal', ->
      expressionFor('  "a string"  ').should.eql aString

    it 'number to a Literal', ->
      expressionFor(' 10.5 ').should.eql aNumber

    it 'sequence to a Sequence', ->
      expressionFor(' [  10.5, "a string"]').should.eql new Sequence('[  10.5, "a string"]', [ aNumber, aString ] )

    it 'empty sequence to a Sequence', ->
      expressionFor('[ ] ').should.eql new Sequence('[ ]', [])

    it 'aggregation to an Aggregation', ->
      expressionFor(' {abc1_: " a string ", _a_Num:10.5}  ').should.eql new Aggregation('{abc1_: " a string ", _a_Num:10.5}', {
        abc1_: new Literal('" a string "', ' a string '),
        _a_Num: new Literal('10.5', 10.5)
      })

  describe 'function calls', ->

    it 'with no arguments', ->
      expressionFor('  theFn ( )  ').should.eql new FunctionCall('theFn ( )', 'theFn', [])


    it 'with no braces', ->
      expressionFor('  theFn ').should.eql new FunctionCall('theFn', 'theFn', [])

    it 'with literal arguments', ->
      expressionFor('theFn(10.5,"a string")').should.eql new FunctionCall('theFn(10.5,"a string")', 'theFn', [aNumber, aString])


  describe 'infix operators', ->

    it 'plus with two operands', ->
      expressionFor(' 10.5 + "a string"').should.eql new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])

    it 'multiply with two operands', ->
      expressionFor('10.5 * "a string" ').should.eql new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])

    it 'subtract with two operands', ->
      expressionFor(' 10.5-22').should.eql new InfixExpression('10.5-22', '-', [aNumber, aNumber22])

    it 'divide with two operands', ->
      expressionFor('10.5/ 22 ').should.eql new InfixExpression('10.5/ 22', '/', [aNumber, aNumber22])


  describe 'function definition', ->

    it 'defining a constant', ->
      functionFor('myFunction = "a string"').should.eql new UserFunction('myFunction', [], aString)

    it 'with no arguments', ->
      functionFor('myFunction = 10.5 / 22').should.eql new UserFunction('myFunction', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

    it 'with two arguments', ->
      functionFor('myFunction(a, bbb) = 10.5 / 22').should.eql new UserFunction('myFunction', ['a', 'bbb'], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

    it 'on multiple lines', ->
      functionFor('myFunction(a, bbb) = \n 10.5 / 22').should.eql new UserFunction('myFunction', ['a', 'bbb'], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

  describe 'a map of function definitions', ->

    it 'with one function', ->
      functionMapFor('myFunction = 10.5 / 22').should.eql { myFunction: new UserFunction('myFunction', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22])) }

    it 'with many functions separated by a semicolon', ->
      functionMapFor('fn1 = 10.5 / 22; \n fn2 (a, bbb) = 22/10.5').should.eql {
        fn1: new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
        fn2: new UserFunction('fn2', ['a', 'bbb'], new InfixExpression('22/10.5', '/', [aNumber22, aNumber]))
      }

    it 'with zero functions', ->
      functionMapFor('   ').should.eql {}