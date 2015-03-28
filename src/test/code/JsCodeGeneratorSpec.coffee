should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression, AggregationSelector} = require '../ast/Expressions'
TextParser = require '../parser/TextParser'
{exprCode, exprFunctionBody, exprFunction} = require './JsCodeGenerator'

describe 'JsCodeGenerator', ->

  code = null
  functionNames = null
  genFor = (expr, functionInfo = {}) -> {code, functionNames} = exprCode expr, functionInfo
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  namedValueCall = (name) -> new FunctionCall(name, name, [])
  aFunctionCall = namedValueCall('a')

  beforeEach ->
    code = null
    functionNames = null

  describe 'Generates code for', ->

    it 'string literal', ->
      genFor new Literal('abc', 'abc')
      code.should.eql '"abc"'

    it 'numeric literal', ->
      genFor new Literal('10.5', 10.5)
      code.should.eql '10.5'

    it 'add expression with two literals', ->
      genFor new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])
      code.should.eql 'operations.add(10.5, "a string")'

    it 'subtract expression with two literals', ->
      genFor new InfixExpression('10.5 - "a string"', '-', [aNumber, aString])
      code.should.eql 'operations.subtract(10.5, "a string")'

    it 'infix expression with two literals', ->
      genFor new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])
      code.should.eql '(10.5 * "a string")'

    it 'not equal expression with two literals', ->
      genFor new InfixExpression('10.5 <> "a string"', '<>', [aNumber, aString])
      code.should.eql '(10.5 != "a string")'

    it 'function call with no arguments', ->
      expr = new FunctionCall('theFn ( )', 'theFn', [])
      genFor expr
      code.should.eql 'theFn'
      functionNames.should.eql ['theFn']

    it 'function call with arguments', ->
      expr = new FunctionCall('theFn (10.5, "a string" )', 'theFn', [aNumber, aString])
      genFor expr
      code.should.eql 'theFn(10.5, "a string")'
      functionNames.should.eql ['theFn']

    it 'function call to transform function', ->
      sourceExpr = new FunctionCall('theSource', 'theSource', [])
      transformExpr = new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])
      expr = new FunctionCall('transformFn (theSource, 10.5 * "a string" )', 'transformFn', [sourceExpr, transformExpr])
      genFor expr, {transformFn: {kind: 'transform'}}
      code.should.eql 'transformFn(theSource, function(_in) { return (10.5 * "a string") })'
      functionNames.should.eql ['transformFn', 'theSource']

    it 'function call to special name in changed to _in and not added to function calls', ->
      expr = new FunctionCall('in', 'in', [])
      genFor expr
      code.should.eql '_in'
      functionNames.should.eql []

    it 'sequence', ->
      genFor new Sequence('[  10.5, "a string"]', [ aNumber, aString ] )
      code.should.eql '[10.5, "a string"]'

    it 'aggregation', ->
      expr = new Aggregation('{abc1_: " a string ", _a_Num:10.5}', {
        abc1_: new Literal('" a string "', ' a string '),
        _a_Num: new Literal('10.5', 10.5)
      })

      genFor expr
      code.should.eql '{abc1_: " a string ", _a_Num: 10.5}'

    it 'aggregation selector', ->
      genFor new AggregationSelector('abc.def', namedValueCall('abc'), 'def')
      code.should.eql '(abc).def'

    it 'a complex expression', ->
      originalCode = '  { a:10, b : x +y, c: [d + 10 - z* 4, "Hi!"]  } '
      expr = new TextParser(originalCode).expression()
      genFor expr

      code.should.eql '{a: 10, b: operations.add(x, y), c: [operations.add(d, operations.subtract(10, (z * 4))), "Hi!"]}'

  describe 'creates function to generate a stream which', ->

    it 'evaluates a simple expression with literals', ->
      expr = new InfixExpression('10.5 * 2', '*', [aNumber, new Literal('2', 2)])
      exprFunctionBody(expr).code.should.eql 'return operations.subject((10.5 * 2));'
      result = null
      operations = subject: (value) -> result = value
      exprFunction(expr, {}).theFunction.apply(null, [operations])
      result.should.eql(21)

    it 'combines two other streams', ->
      expr = new InfixExpression('a * b', '*', [namedValueCall('a'), namedValueCall('b')])
      functionInfo = {}
      exprFunctionBody(expr, functionInfo).code.should.eql 'return operations.combine(a, b, function(a, b) { return (a * b); });'
      exprFunctionBody(expr, functionInfo).functionCalls = ['a', 'b']
      result = null
      operations = combine: (x, y, fn) -> result = fn(x, y)
      exprFunction(expr, functionInfo).theFunction.apply(null, [operations, 5, 6])
      result.should.eql(30)
      exprFunction(expr, functionInfo).functionCalls = ['a', 'b']


  describe 'stores function calls', ->

    it 'only the first time found', ->
      genFor new InfixExpression('a * a', '*', [aFunctionCall, aFunctionCall])

      functionNames.should.eql ['a']
