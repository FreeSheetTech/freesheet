should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression} = require '../ast/Expressions'
JsCodeGenerator = require './JsCodeGenerator'

describe 'Generates code for', ->

  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)


  it 'string literal', ->
    codeGen = new JsCodeGenerator(new Literal('abc', 'abc'))
    codeGen.code.should.eql '"abc"'

  it 'numeric literal', ->
    codeGen = new JsCodeGenerator(new Literal('10.5', 10.5))
    codeGen.code.should.eql '10.5'

  it 'infix expression with two literals', ->
    expr = new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])
    codeGen = new JsCodeGenerator(expr)
    codeGen.code.should.eql '10.5 + "a string"'