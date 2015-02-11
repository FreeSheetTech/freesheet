should = require 'should'
Rx = require 'rx'
{TextParser} = require '../parser/TextParser'
{ReactiveRunner} = require './ReactiveRunner'


describe 'ReactiveRunner runs', ->

  runner = null
  changes = null

  parse = (text) -> new TextParser(text).functionDefinitionMap()
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)
  valuesReceivedBySubject = (subject) ->
    values = []
    subject.subscribe (value) -> values.push value
    values

  callback = (name, value) -> received = {}; received[name] = value; changes.push received

  beforeEach ->
    runner = new ReactiveRunner()
    changes = []
    runner.onChange callback

  it 'function with no args returning constant', ->
    parseUserFunctions ''' theAs = "aaaAAA" '''

#    subject = runner.output 'theAs'
#    valueReceived = null
#    subject.subscribe (value) -> valueReceived = value

    valuesReceivedBySubject(runner.output('theAs')).should.eql ["aaaAAA"]

  it 'notifies a change to a constant value formula when it is set and changed', ->
    parseUserFunctions 'price = 22.5; tax_rate = 0.2'
    parseUserFunctions 'price = 33.5'

    changes.should.eql [{price:22.5}, {'tax_rate':0.2}, {price: 33.5}]


  it 'function with no args returning constant calculated addition expression', ->
    scriptFunctions = parse '''twelvePlusThree = 12 + 3 '''
    runner = new ReactiveRunner({}, scriptFunctions)

    subject = runner.output 'twelvePlusThree'
    valueReceived = null
    subject.subscribe (value) -> valueReceived = value

    valueReceived.should.eql 15

  it 'function with no args returning another function with no args', ->
    scriptFunctions = parse '''twelvePlusThree = 12 + 3; five = twelvePlusThree / 3 '''
    runner = new ReactiveRunner({}, scriptFunctions)

    subject = runner.output 'five'
    valueReceived = null
    subject.subscribe (value) -> valueReceived = value

    valueReceived.should.eql 5

  it 'function using a built-in function', ->
    builtInFunctions = { theInput: -> new Rx.BehaviorSubject(20) }
    scriptFunctions = parse '''inputMinusTwo = theInput() - 2 '''
    runner = new ReactiveRunner(builtInFunctions, scriptFunctions)

    subject = runner.output 'inputMinusTwo'
    valueReceived = null
    subject.subscribe (value) -> valueReceived = value

    valueReceived.should.eql 18


#  it 'function with one arg which is a literal', ->
#    scriptFunctions = parse '''addFive(n) = n + 5; total = addFive(14)'''
#    runner = new ReactiveRunner({}, scriptFunctions)
#
#    subject = runner.output 'total'
#    valueReceived = null
#    subject.subscribe (value) -> valueReceived = value
#
#    valueReceived.should.eql 19
#
#  it 'function with one arg which is a constant expression', ->
#    scriptFunctions = parse '''twelvePlusThree = 12 + 3; addFive(n) = n + 5; total = addFive(twelvePlusThree)'''
#    runner = new ReactiveRunner({}, scriptFunctions)
#
#    subject = runner.output 'total'
#    valueReceived = null
#    subject.subscribe (value) -> valueReceived = value
#
#    valueReceived.should.eql 20
