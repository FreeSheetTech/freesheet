should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression, AggregationSelector} = require '../ast/Expressions'
TextParser = require '../parser/TextParser'
JsCodeGenerator = require './JsCodeGenerator'

describe 'JsCodeGenerator', ->

  @timeout 5000

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

    it 'sequence', ->
      codeGen = genFor new Sequence('[  10.5, "a string"]', [ aNumber, aString ] )
      codeGen.code.should.eql '[10.5, "a string"]'

    it 'aggregation', ->
      expr = new Aggregation('{abc1_: " a string ", _a_Num:10.5}', {
        abc1_: new Literal('" a string "', ' a string '),
        _a_Num: new Literal('10.5', 10.5)
      })

      codeGen = genFor expr
      codeGen.code.should.eql '{abc1_: " a string ", _a_Num: 10.5}'

    it 'aggregation selector', ->
      codeGen = genFor new AggregationSelector('abc.def', namedValueCall('abc'), 'def')
      codeGen.code.should.eql 'abc.def'

    it 'a complex expression', ->
      originalCode = '  { a:10, b : x +y, c: [d + 10 - z* 4, "Hi!"]  } '
      expr = new TextParser(originalCode).expression()
      codeGen = genFor expr

      codeGen.code.should.eql '{a: 10, b: x + y, c: [d + 10 - z * 4, "Hi!"]}'

  describe 'stores function calls', ->

    it 'only the first time found', ->
      codeGen = genFor new InfixExpression('a * a', '*', [aFunctionCall, aFunctionCall])

      codeGen.functionCalls.should.eql [aFunctionCall]
