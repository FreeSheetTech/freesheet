should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression, AggregationSelector} = require '../ast/Expressions'
TextParser = require '../parser/TextParser'
JsCodeGenerator = require './JsCodeGenerator'

describe 'JsCodeGenerator', ->

  genFor = (expr, contextName, transformFunctionNames = []) -> new JsCodeGenerator expr, contextName, transformFunctionNames
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

    it 'add expression with two literals', ->
      codeGen = genFor new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])
      codeGen.code.should.eql 'operations.add(10.5, "a string")'

    it 'subtract expression with two literals', ->
      codeGen = genFor new InfixExpression('10.5 - "a string"', '-', [aNumber, aString])
      codeGen.code.should.eql 'operations.subtract(10.5, "a string")'

    it 'infix expression with two literals', ->
      codeGen = genFor new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])
      codeGen.code.should.eql '(10.5 * "a string")'

    it 'not equal expression with two literals', ->
      codeGen = genFor new InfixExpression('10.5 <> "a string"', '<>', [aNumber, aString])
      codeGen.code.should.eql '(10.5 != "a string")'

    it 'function call with no arguments', ->
      expr = new FunctionCall('theFn ( )', 'theFn', [])
      codeGen = genFor expr
      codeGen.code.should.eql 'theFn'
      codeGen.functionCalls.should.eql [expr]

    it 'function call with arguments', ->
      expr = new FunctionCall('theFn (10.5, "a string" )', 'theFn', [aNumber, aString])
      codeGen = genFor expr
      codeGen.code.should.eql 'theFn(10.5, "a string")'
      codeGen.functionCalls.should.eql [expr]

    it 'function call to transform function', ->
      sourceExpr = new FunctionCall('theSource', 'theSource', [])
      transformExpr = new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])
      expr = new FunctionCall('transformFn (theSource, 10.5 * "a string" )', 'transformFn', [sourceExpr, transformExpr])
      codeGen = genFor expr, '', ['transformFn']
      codeGen.code.should.eql 'transformFn(theSource, function(_in) { return (10.5 * "a string") })'
      codeGen.functionCalls.should.eql [expr, sourceExpr]

    it 'function call to special name in changed to _in and not added to function calls', ->
      expr = new FunctionCall('in', 'in', [])
      codeGen = genFor expr
      codeGen.code.should.eql '_in'
      codeGen.functionCalls.should.eql []

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
      codeGen.code.should.eql '(abc).def'

    it 'a complex expression', ->
      originalCode = '  { a:10, b : x +y, c: [d + 10 - z* 4, "Hi!"]  } '
      expr = new TextParser(originalCode).expression()
      codeGen = genFor expr

      codeGen.code.should.eql '{a: 10, b: operations.add(x, y), c: [operations.add(d, operations.subtract(10, (z * 4))), "Hi!"]}'

  describe 'stores function calls', ->

    it 'only the first time found', ->
      codeGen = genFor new InfixExpression('a * a', '*', [aFunctionCall, aFunctionCall])

      codeGen.functionCalls.should.eql [aFunctionCall]
