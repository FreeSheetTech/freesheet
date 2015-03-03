should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression} = require '../ast/Expressions'
JsCodeGenerator = require './JsCodeGenerator'

describe 'JsCodeGenerator', ->

  genFor = (expr) -> new JsCodeGenerator expr
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  namedValueCall = (name) -> new FunctionCall(name, name, [])
  aFunctionCall = namedValueCall('a')

  describe 'Generates code for', ->

    it 'string literal', ->
      codeGen = genFor new Literal('abc', 'abc')
      codeGen.code.should.eql '"abc"'

    it 'numeric literal', ->
      codeGen = genFor new Literal('10.5', 10.5)
      codeGen.code.should.eql '10.5'

    it 'infix expression with two literals', ->
      codeGen = genFor new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])
      codeGen.code.should.eql '10.5 + "a string"'

    it 'function call with no arguments', ->
      expr = new FunctionCall('theFn ( )', 'theFn', [])
      codeGen = genFor expr
      codeGen.code.should.eql 'theFn'
      codeGen.functionCalls.should.eql [expr]

  describe 'stores function calls', ->

    it 'only the first time found', ->
      codeGen = genFor new InfixExpression('a * a', '*', [aFunctionCall, aFunctionCall])

      codeGen.functionCalls.should.eql [aFunctionCall]
