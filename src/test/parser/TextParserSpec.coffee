should = require 'should'
TextParser = require './TextParser'
{Literal, Sequence, Aggregation, FunctionCall, AggregationSelector, Input} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'


describe 'TextParser parses', ->

  @timeout 10000

  expressionFor = (text) -> new TextParser(text).expression()
  functionFor = (text) -> new TextParser(text).functionDefinition()
  functionMapFor = (text) -> new TextParser(text).functionDefinitionMap()
  functionListFor = (text) -> new TextParser(text).functionDefinitionList()
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)
  trueLit = new Literal('true', true)
  noLit = new Literal('no', false)
  namedValueCall = (name) -> new FunctionCall(name, name, [])
  aFunctionCall = namedValueCall('a')

  describe 'expressions', ->

    it 'none to a Literal', ->
      expressionFor('  none  ').should.eql new Literal('none', null)

    it 'booleans to a Literal', ->
      expressionFor('  true  ').should.eql new Literal('true', true)
      expressionFor('yes  ').should.eql new Literal('yes', true)
      expressionFor('false').should.eql new Literal('false', false)
      expressionFor('no').should.eql new Literal('no', false)

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

    it 'which start with literal names', ->
      expressionFor('nonesuch').should.eql new FunctionCall('nonesuch', 'nonesuch', [])
      expressionFor('yesitdoes()').should.eql new FunctionCall('yesitdoes()', 'yesitdoes', [])

    it 'with no braces', ->
      expressionFor('  theFn ').should.eql new FunctionCall('theFn', 'theFn', [])

    it 'with literal arguments', ->
      expressionFor('theFn(10.5,"a string")').should.eql new FunctionCall('theFn(10.5,"a string")', 'theFn', [aNumber, aString])

    it 'with aggregate expression arguments', ->
      expressionFor('fromEach(dataItems,{a:x, b: 10.5, c: y})').should.eql new FunctionCall('fromEach(dataItems,{a:x, b: 10.5, c: y})', 'fromEach', [
        new FunctionCall('dataItems', 'dataItems', [])
        new Aggregation('{a:x, b: 10.5, c: y}', {
          a: namedValueCall 'x'
          b: aNumber
          c: namedValueCall 'y'
        })
      ])


  describe 'infix operators', ->

    describe 'arithmetic', ->

      it 'plus with two operands', ->
        expressionFor(' 10.5 + "a string"').should.eql new InfixExpression('10.5 + "a string"', '+', [aNumber, aString])

      it 'multiply with two operands', ->
        expressionFor('10.5 * "a string" ').should.eql new InfixExpression('10.5 * "a string"', '*', [aNumber, aString])

      it 'subtract with two operands', ->
        expressionFor(' 10.5-22').should.eql new InfixExpression('10.5-22', '-', [aNumber, aNumber22])

      it 'divide with two operands', ->
        expressionFor('10.5/ 22 ').should.eql new InfixExpression('10.5/ 22', '/', [aNumber, aNumber22])

    describe 'comparative', ->

      it 'less than with two operands', ->
        expressionFor(' 10.5 < 22').should.eql new InfixExpression('10.5 < 22', '<', [aNumber, aNumber22])

      it 'greater than with two operands', ->
        expressionFor('10.5 > 22 ').should.eql new InfixExpression('10.5 > 22', '>', [aNumber, aNumber22])

      it 'less than or equal with two operands', ->
        expressionFor(' 10.5<=22').should.eql new InfixExpression('10.5<=22', '<=', [aNumber, aNumber22])

      it 'greater than or equal with two operands', ->
        expressionFor('10.5>= 22 ').should.eql new InfixExpression('10.5>= 22', '>=', [aNumber, aNumber22])

      it 'equal with two operands', ->
        expressionFor('a == 22 ').should.eql new InfixExpression('a == 22', '==', [aFunctionCall, aNumber22])

      it 'not equal with two operands', ->
        expressionFor('a <> 22 ').should.eql new InfixExpression('a <> 22', '<>', [aFunctionCall, aNumber22])

    describe 'logical', ->

      it 'and with two operands', ->
        expressionFor(' 10.5 and true ').should.eql new InfixExpression('10.5 and true', 'and', [aNumber, trueLit])

      it 'or with two operands', ->
        expressionFor(' 10.5 or true ').should.eql new InfixExpression('10.5 or true', 'or', [aNumber, trueLit])


    describe 'precedence', ->

      it 'multiplication higher than addition', ->
        expressionFor('10.5 + a * 22').should.eql new InfixExpression('10.5 + a * 22', '+', [
                                                   aNumber,
                                                   new InfixExpression('a * 22', '*', [aFunctionCall, aNumber22])
        ])

      it 'multiplication and division both higher than addition and subtraction', ->
        expressionFor('22 / 10.5 + a * 22 - 10.5').should.eql new InfixExpression('22 / 10.5 + a * 22 - 10.5', '+', [
                                                   new InfixExpression('22 / 10.5', '/', [aNumber22, aNumber]),
                                                   new InfixExpression('a * 22 - 10.5', '-', [
                                                     new InfixExpression('a * 22', '*', [aFunctionCall, aNumber22]),
                                                     aNumber
                                                   ])
        ])

      it 'addition higher than comparison', ->
        expressionFor('22 - 10.5 > a + 22').should.eql new InfixExpression('22 - 10.5 > a + 22', '>', [
          new InfixExpression('22 - 10.5', '-', [aNumber22, aNumber]),
          new InfixExpression('a + 22', '+', [aFunctionCall, aNumber22])
        ])

      it 'dot operator higher than addition', ->
        expressionFor('abc.def + 10.5').should.eql new InfixExpression('abc.def + 10.5', '+', [
          new AggregationSelector('abc.def', namedValueCall('abc'), 'def'),
          aNumber
        ])

      it 'dot operator higher than multiplication', ->
        expressionFor('abc.def * 10.5').should.eql new InfixExpression('abc.def * 10.5', '*', [
          new AggregationSelector('abc.def', namedValueCall('abc'), 'def'),
          aNumber
        ])

      it 'comparative higher than and', ->
        expressionFor('true and 10.5 > 22').should.eql new InfixExpression('true and 10.5 > 22', 'and', [
          trueLit,
          new InfixExpression('10.5 > 22', '>', [aNumber, aNumber22])
        ])

      it 'comparative higher than or', ->
        expressionFor('true or 10.5 > 22').should.eql new InfixExpression('true or 10.5 > 22', 'or', [
          trueLit,
          new InfixExpression('10.5 > 22', '>', [aNumber, aNumber22])
        ])

      it 'and higher than or', ->
        expressionFor('true or 10.5 and 22').should.eql new InfixExpression('true or 10.5 and 22', 'or', [
          trueLit,
          new InfixExpression('10.5 and 22', 'and', [aNumber, aNumber22])
        ])

      it 'and really higher than or', ->
        expressionFor('true and 10.5 or 22').should.eql new InfixExpression('true and 10.5 or 22', 'or', [
          new InfixExpression('true and 10.5', 'and', [trueLit, aNumber])
          aNumber22
        ])

  describe 'select from structures', ->

    it 'dot operator for element of aggregation', ->
      expressionFor('abc.def').should.eql new AggregationSelector('abc.def', namedValueCall('abc'), 'def')


  describe 'function definition', ->

    it 'defining a constant', ->
      functionFor('myFunction = "a string"').should.eql new UserFunction('myFunction', [], aString)

    it 'with no arguments', ->
      functionFor('myFunction = 10.5 / 22').should.eql new UserFunction('myFunction', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

    it 'with two arguments', ->
      functionFor('myFunction(a, bbb) = 10.5 / 22').should.eql new UserFunction('myFunction', ['a', 'bbb'], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

    it 'on multiple lines', ->
      functionFor('myFunction(a, bbb) = \n 10.5 / 22').should.eql new UserFunction('myFunction', ['a', 'bbb'], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))

    it 'with medium complex expression', ->
      functionQ = functionFor('q = getTheAnswer(100, b+a, getTheAnswer ( 4, 10, 12, 14)  )')
      functionQ.constructor.name.should.eql 'UserFunction'

    it 'with complex expression', ->
      functionQ = functionFor('q = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )')
      functionQ.constructor.name.should.eql 'UserFunction'

    it 'with a syntax error', ->
      functionQ = functionFor('  q = getTheAnswer(100}  ')
      functionQ.constructor.name.should.eql 'FunctionError'
      functionQ.name.should.eql 'q'
      functionQ.expr.should.eql {text: 'getTheAnswer(100}'}
      functionQ.error.toString().should.match /^SyntaxError/
      functionQ.error.line.should.equal 1
      functionQ.error.column.should.equal 21
      functionQ.error.columnInExpr.should.equal 17

    it 'for an input', ->
      def = functionFor('myInput = input')
      def.expr.should.be.instanceof Input
      def.expr.isInput.should.equal true
      def.should.eql new UserFunction('myInput', [], new Input("myInput"))

    it 'for a function name that starts with input', ->
      def = functionFor('myFunction = inputValidated')
      def.expr.should.be.instanceof FunctionCall
      def.should.eql new UserFunction('myFunction', [], namedValueCall('inputValidated'))

  describe 'a map of function definitions', ->

    it 'with one function', ->
      functionMapFor('myFunction = 10.5 / 22').should.eql { myFunction: new UserFunction('myFunction', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22])) }

    it 'with many functions separated by a semicolon', ->
      functionMapFor('fn1 = 10.5 / 22; \n fn2 (a, bbb) = 22/10.5').should.eql {
        fn1: new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
        fn2: new UserFunction('fn2', ['a', 'bbb'], new InfixExpression('22/10.5', '/', [aNumber22, aNumber]))
      }

    it 'with many functions separated by a semicolon, as a list', ->
      functionListFor('fn1 = 10.5 / 22; \n fn2 (a, bbb) = 22/10.5').should.eql [
          new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22])),
          new UserFunction('fn2', ['a', 'bbb'], new InfixExpression('22/10.5', '/', [aNumber22, aNumber]))
        ]


#      TODO make parser recognise newlines to separate functions
#    it 'with many functions separated by a newline', ->
#      functionMapFor('fn1 = 10.5 / 22\nfn2  = 22/10.5').should.eql {
#        fn1: new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
#        fn2: new UserFunction('fn2', ['a', 'bbb'], new InfixExpression('22/10.5', '/', [aNumber22, aNumber]))
#      }

    it 'with zero functions', ->
      functionMapFor('   ').should.eql {}

    it 'with complex expression', ->
      functionQ = functionMapFor('q() = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )')['q']
      functionQ.should.be.instanceof UserFunction
