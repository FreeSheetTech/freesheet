should = require 'should'
{TextParser} = require './TextParser'
{Literal, Sequence, Aggregation, FunctionCall} = require '../ast/Expressions'


describe 'TextParser', ->

  astFor = (text) -> new TextParser(text).ast()

  describe 'parses expressions', ->

    it 'string to a Literal', ->
      astFor('  "a string"  ').should.eql new Literal('"a string"', 'a string')

    it 'number to a Literal', ->
      astFor(' 10.5 ').should.eql new Literal('10.5', 10.5)

    it 'sequence to a Sequence', ->
      astFor(' [  10.5, "a string"]').should.eql new Sequence('[  10.5, "a string"]', [
        new Literal('10.5', 10.5)
        new Literal('"a string"', 'a string')
      ])

    it 'empty sequence to a Sequence', ->
      astFor('[ ] ').should.eql new Sequence('[ ]', [])

    it 'aggregation to an Aggregation', ->
      astFor(' {abc1_: " a string ", _a_Num:10.5}  ').should.eql new Aggregation('{abc1_: " a string ", _a_Num:10.5}', {
        abc1_: new Literal('" a string "', ' a string '),
        _a_Num: new Literal('10.5', 10.5)
      })

  describe 'parses function calls', ->

    it 'with no arguments', ->
      astFor('  theFn ( )  ').should.eql new FunctionCall('theFn ( )', 'theFn', [])

    it 'with literal arguments', ->
      astFor('theFn(10.5,"a string")').should.eql new FunctionCall('theFn(10.5,"a string")', 'theFn', [new Literal('10.5', 10.5), new Literal('"a string"', 'a string')])

