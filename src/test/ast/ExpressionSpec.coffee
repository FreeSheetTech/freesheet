should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall} = require './Expressions'

describe 'Expressions', ->

  it 'Literal stores text and value', ->
    stringLit = new Literal('abc', 'abc')
    stringLit.text.should.eql 'abc'
    stringLit.value.should.eql 'abc'
    stringLit.children.should.eql []

    numLit = new Literal('10.5', 10)
    numLit.text.should.eql '10.5'
    numLit.value.should.eql 10

  it 'Sequence stores text and children', ->
    seq = new Sequence('a seq', ['x', 10])
    seq.text.should.eql 'a seq'
    seq.children.should.eql ['x', 10]

  it 'Aggregation stores text, children and map of names to children', ->
    agg = new Aggregation('an agg', {aaa: 10, bbb: 'yy'})
    agg.text.should.eql 'an agg'
    agg.children.should.eql [10, 'yy']
    agg.childMap.should.eql {aaa: 10, bbb: 'yy'}

  it 'FunctionCall stores text, function name and children', ->
    fc = new FunctionCall('the function', 'fn1', ['a', 55])
    fc.text.should.eql 'the function'
    fc.functionName.should.eql 'fn1'
    fc.children.should.eql ['a', 55]