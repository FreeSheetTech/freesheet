should = require 'should'
{Literal, Sequence, Aggregation, FunctionCall, InfixExpression, AggregationSelector} = require '../ast/Expressions'
TextParser = require '../parser/TextParser'
{exprCode, exprFunctionBody, exprFunction} = require './JsCodeGenerator'

describe 'JsCodeGenerator', ->

  code = null
  functionNames = null
  genFor = (expr, functionInfo = {}) -> {code, functionNames} = exprCode expr, functionInfo; code
  genBodyFor = (expr, functionInfo = {}) -> {code, functionNames} = exprFunctionBody expr, functionInfo
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  namedValueCall = (name) -> new FunctionCall(name, name, [])
  aFunctionCall = namedValueCall('a')

  beforeEach ->
    code = null
    functionNames = null

  describe 'Generates code for', ->

    it 'none', ->
      genFor new Literal(' none ', null)
      code.should.eql 'null'

    it 'boolean literals', ->
      genFor( new Literal('true', true)).should.eql( 'true' )
      genFor( new Literal(' no ', false)).should.eql( 'false' )

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

    it 'and expression with two literals', ->
      genFor new InfixExpression('10.5 and "a string"', 'and', [aNumber, aString])
      code.should.eql '(10.5 && "a string")'

    it 'or expression with two literals', ->
      genFor new InfixExpression('10.5 or "a string"', 'or', [aNumber, aString])
      code.should.eql '(10.5 || "a string")'

    it 'function call with no arguments', ->
      expr = new FunctionCall('theFn ( )', 'theFn', [])
      genFor expr
      code.should.eql '_ctx.theFn'
      functionNames.should.eql ['theFn']

    it 'function call with arguments', ->
      expr = new FunctionCall('theFn (10.5, "a string" )', 'theFn', [aNumber, aString])
      genFor expr
      code.should.eql '_ctx.theFn(10.5, "a string")'
      functionNames.should.eql ['theFn']

    it 'function call to transform function', ->
      sourceExpr = new FunctionCall('theSource', 'theSource', [])
      transformExpr = new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])
      expr = new FunctionCall('transformFn (theSource, 10.5 * "a string" )', 'transformFn', [sourceExpr, transformExpr])
      genFor expr, {transformFn: {kind: 'transform'}}
      code.should.eql '_ctx.transformFn(_ctx.theSource, function(_in) { return (10.5 * "a string") })'
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
      code.should.eql 'function() { var abc1_ = \" a string \",\n    _a_Num = 10.5;\nreturn {abc1_: abc1_, _a_Num: _a_Num}; }()'

    it 'aggregation selector', ->
      genFor new AggregationSelector('abc.def', namedValueCall('abc'), 'def')
      code.should.eql '(_ctx.abc).def'

    it 'a complex expression', ->
      originalCode = '  { a:10, b : x +y, c: [d + 10 - z* 4, "Hi!"]  } '
      expr = new TextParser(originalCode).expression()
      genFor expr

      code.should.eql 'function() { var a = 10,\n    b = operations.add(_ctx.x, _ctx.y),\n    c = [operations.add(_ctx.d, operations.subtract(10, (_ctx.z * 4))), \"Hi!\"];\nreturn {a: a, b: b, c: c}; }()'

  describe 'creates function to generate a stream which', ->

    it 'evaluates a simple expression with literals', ->
      expr = new InfixExpression('10.5 * 2', '*', [aNumber, new Literal('2', 2)])
      genBodyFor expr
      code.should.eql 'return operations.subject((10.5 * 2));'

      result = null
      operations = subject: (value) -> result = value
      exprFunction(expr, {}).theFunction.apply(null, [operations])
      result.should.eql(21)

    it 'combines two other streams', ->
      expr = new InfixExpression('a * b', '*', [namedValueCall('a'), namedValueCall('b')])
      functionInfo = {}
      genBodyFor expr, functionInfo
      code.should.eql 'return operations.combine(_ctx.a, _ctx.b, function(a, b) { return (a * b); });'
      functionNames.should.eql ['a', 'b']

      result = null
      operations = combine: (x, y, fn) -> result = fn(x, y)
      exprFunction(expr, functionInfo).theFunction.apply(null, [operations, {a:5, b:6}])
      result.should.eql(30)
      exprFunction(expr, functionInfo).functionCalls = ['a', 'b']

    it 'combines a transform function and another stream', ->
      expr = new FunctionCall('fromEach( games, 10.5 )', 'fromEach', [namedValueCall('games'), aNumber])
      functionInfo = fromEach: {kind: 'transform'}
      genBodyFor expr, functionInfo
      code.should.eql 'return operations.combine(_ctx.fromEach, _ctx.games, function(fromEach, games) { return fromEach(games, function(_in) { return 10.5 }); });'
      functionNames.should.eql ['fromEach', 'games']


    it 'combines streams into an aggregate with local names', ->
      originalCode = 'fromEach( games, {basicTime: in.time, fullTime: basicTime + 2, maxTime: fullTime + 3} )'
      expr = new TextParser(originalCode).expression()
      functionInfo = fromEach: {kind: 'transform'}

      genBodyFor expr, functionInfo
      code.should.eql 'return operations.combine(_ctx.fromEach, _ctx.games, function(fromEach, games) { return fromEach(games, function(_in) { return function() { var basicTime = (_in).time,\n    fullTime = operations.add(basicTime, 2),\n    maxTime = operations.add(fullTime, 3);\nreturn {basicTime: basicTime, fullTime: fullTime, maxTime: maxTime}; }() }); });'
      functionNames.should.eql ['fromEach', 'games']

    it 'gets an input', ->
      expr = new Input("anInput")
      genBodyFor expr
      code.should.eql 'return operations.input("anInput");'



  describe 'Generates code for calls to stream functions', ->

    functionInfo =
      total: {kind: 'stream'}
      average: {kind: 'stream'}

    it 'with one argument', ->
      genBodyFor new FunctionCall('total(b)', 'total', [namedValueCall('b')]), functionInfo
      code.should.eql 'var total_1 = _ctx.total(_ctx.b);\nreturn total_1;'
      functionNames.should.eql ['total', 'b']

    it 'with one argument which is a normal function call', ->
      genBodyFor new FunctionCall('total(addFive(b))', 'total', [new FunctionCall('addFive(b)', 'addFive', [namedValueCall('b')])]), functionInfo
      code.should.eql 'var total_1 = _ctx.total(operations.combine(_ctx.addFive, _ctx.b, function(addFive, b) { return addFive(b); }));\nreturn total_1;'
      functionNames.should.eql ['total', 'addFive', 'b']

    it 'inside a normal function', ->
      genBodyFor new FunctionCall('addFive(total(b))', 'addFive', [new FunctionCall('total(b)', 'total', [namedValueCall('b')])]), functionInfo
      code.should.eql 'var total_1 = _ctx.total(_ctx.b);\nreturn operations.combine(_ctx.addFive, total_1, function(addFive, total_1) { return addFive(total_1); });'
      functionNames.should.eql ['addFive', 'total', 'b']

    it 'with an expression as an argument', ->
      originalCode = 'addFive( total( addTen(c) * addFive(d) ) / addTen(e))'
      expr = new TextParser(originalCode).expression()
      genBodyFor expr, functionInfo

      code.should.eql '''var total_1 = _ctx.total(operations.combine(_ctx.addTen, _ctx.c, _ctx.addFive, _ctx.d, function(addTen, c, addFive, d) { return (addTen(c) * addFive(d)); }));
                         return operations.combine(_ctx.addFive, total_1, _ctx.addTen, _ctx.e, function(addFive, total_1, addTen, e) { return addFive((total_1 / addTen(e))); });'''
      functionNames.should.eql ['addFive', 'total', 'addTen', 'c', 'd', 'e']

    it 'complex expression with multiple streams at different levels and function used twice in one combine', ->
      originalCode = 'addFive( total( addTen(c) * addFive( average( c * total(addTen(d)) ) / addTen(e))))'
      expr = new TextParser(originalCode).expression()
      genBodyFor expr, functionInfo

      code.should.eql '''var total_1 = _ctx.total(operations.combine(_ctx.addTen, _ctx.d, function(addTen, d) { return addTen(d); }));
                         var average_1 = _ctx.average(operations.combine(_ctx.c, total_1, function(c, total_1) { return (c * total_1); }));
                         var total_2 = _ctx.total(operations.combine(_ctx.addTen, _ctx.c, _ctx.addFive, average_1, _ctx.e, function(addTen, c, addFive, average_1, e) { return (addTen(c) * addFive((average_1 / addTen(e)))); }));
                         return operations.combine(_ctx.addFive, total_2, function(addFive, total_2) { return addFive(total_2); });'''
      functionNames.should.eql ['addFive', 'total', 'addTen', 'c', 'average', 'd', 'e']


  describe 'stores function calls', ->

    it 'only the first time found', ->
      genFor new InfixExpression('a * a', '*', [aFunctionCall, aFunctionCall])
      functionNames.should.eql ['a']


