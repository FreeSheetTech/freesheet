should = require 'should'
{TextParser} = require './TextParser'
{Literal, Sequence, Aggregation, FunctionCall} = require '../ast/Expressions'


describe 'TextParser parses', ->

  astFor = (text) -> new TextParser(text).ast()
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)

  describe 'expressions', ->

    it 'string to a Literal', ->
      astFor('  "a string"  ').should.eql aString

    it 'number to a Literal', ->
      astFor(' 10.5 ').should.eql aNumber

    it 'sequence to a Sequence', ->
      astFor(' [  10.5, "a string"]').should.eql new Sequence('[  10.5, "a string"]', [ aNumber, aString ] )

    it 'empty sequence to a Sequence', ->
      astFor('[ ] ').should.eql new Sequence('[ ]', [])

    it 'aggregation to an Aggregation', ->
      astFor(' {abc1_: " a string ", _a_Num:10.5}  ').should.eql new Aggregation('{abc1_: " a string ", _a_Num:10.5}', {
        abc1_: new Literal('" a string "', ' a string '),
        _a_Num: new Literal('10.5', 10.5)
      })

  describe 'function calls', ->

    it 'with no arguments', ->
      astFor('  theFn ( )  ').should.eql new FunctionCall('theFn ( )', 'theFn', [])

    it 'with literal arguments', ->
      astFor('theFn(10.5,"a string")').should.eql new FunctionCall('theFn(10.5,"a string")', 'theFn', [aNumber, aString])


  describe 'infix operators', ->

    it 'plus with two operands', ->
      astFor(' 10.5 + "a string"').should.eql new InfixExpression('10.5 + "a string"', '+', aNumber, aString)

    it 'multiply with two operands', ->
      astFor('10.5 * "a string" ').should.eql new InfixExpression('10.5 * "a string"', '*', aNumber, aString)

    it 'subtract with two operands', ->
      astFor(' 10.5-22').should.eql new InfixExpression('10.5-22', '-', aNumber, aNumber22)

    it 'divide with two operands', ->
      astFor('10.5/ 22 ').should.eql new InfixExpression('10.5/ 22', '/', aNumber, aNumber22)


