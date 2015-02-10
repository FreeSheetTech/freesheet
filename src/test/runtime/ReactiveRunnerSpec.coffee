should = require 'should'
{TextParser} = require '../parser/TextParser'
{ReactiveRunner} = require './ReactiveRunner'


describe 'ReactiveRunner runs', ->

  parse = (text) -> new TextParser(text).functionDefinitionMap()

  it 'function with no args returning constant', ->
    scriptFunctions = parse ''' theAs = "aaaAAA" '''
    runner = new ReactiveRunner({}, scriptFunctions)

    subject = runner.output 'theAs'
    valueReceived = null
    subject.subscribe (value) -> valueReceived = value

    valueReceived.should.eql "aaaAAA"

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
