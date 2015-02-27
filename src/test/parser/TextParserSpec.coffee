should = require 'should'
TextParser = require './TextParser'
{Literal, Sequence, Aggregation, FunctionCall} = require '../ast/Expressions'
{UserFunction, ArgumentDefinition} = require '../ast/FunctionDefinition'


describe 'TextParser parses', ->

  @timeout 5000

  expressionFor = (text) -> new TextParser(text).expression()
  functionFor = (text) -> new TextParser(text).functionDefinition()
  functionMapFor = (text) -> new TextParser(text).functionDefinitionMap()
  aString = new Literal('"a string"', 'a string')
  aNumber = new Literal('10.5', 10.5)
  aNumber22 = new Literal('22', 22)
  namedValueCall = (name) -> new FunctionCall(name, name, [])
  aFunctionCall = namedValueCall('a')

  describe 'expressions', ->

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
      startTime = Date.now()
      functionQ = functionFor('q = getTheAnswer(100, b+a, getTheAnswer ( 4, 10, 12, 14)  )')
      functionQ.constructor.name.should.eql 'UserFunction'
      elapsedTime = Date.now - startTime
      console.log 'Elapsed', elapsedTime

    it 'with complex expression', ->
      console.log Date.now()
      functionQ = functionFor('q = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )')
      console.log Date.now()

      console.log 'functionQ', functionQ.constructor.name
      console.log Date.now()

      functionQ.constructor.name.should.eql 'UserFunction'
      console.log Date.now()


  describe 'a map of function definitions', ->

    it 'with one function', ->
      functionMapFor('myFunction = 10.5 / 22').should.eql { myFunction: new UserFunction('myFunction', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22])) }

    it 'with many functions separated by a semicolon', ->
      functionMapFor('fn1 = 10.5 / 22; \n fn2 (a, bbb) = 22/10.5').should.eql {
        fn1: new UserFunction('fn1', [], new InfixExpression('10.5 / 22', '/', [aNumber, aNumber22]))
        fn2: new UserFunction('fn2', ['a', 'bbb'], new InfixExpression('22/10.5', '/', [aNumber22, aNumber]))
      }

    it 'with zero functions', ->
      functionMapFor('   ').should.eql {}

    it 'with complex expression', ->
      functionQ = functionMapFor('q() = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )')['q']
      console.log 'functionQ', functionQ
      functionQ.should.be.instanceof UserFunction
