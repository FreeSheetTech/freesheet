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
