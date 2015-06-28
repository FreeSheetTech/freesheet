should = require 'should'
TextParser = require '../parser/TextParser'
ReactiveRunner = require './ReactiveRunner'
RunnerEnvironment = require './RunnerEnvironment'
{CalculationError} = require '../error/Errors'

describe 'RunnerEnvironment', ->

  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (runner, text) -> runner.addUserFunctions parse(text)


  it 'allows references from one runner to another', ->
    changes = []
    callback = (name, value) -> received = {}; received[name] = value; changes.push received

    runnerA = new ReactiveRunner()
    runnerB = new ReactiveRunner()
    runnerB.onValueChange callback

    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerA', runnerA
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerA, 'x = 10; y = x * 2'
    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    parseUserFunctions runnerA, 'y = x * 3'

    changes.should.eql [{z:20}, {z: 30}]

  it 'gives an error when sheet does not exist', ->
    changes = []
    callback = (name, value) -> received = {}; received[name] = value; changes.push received

    runnerB = new ReactiveRunner()
    runnerB.onValueChange callback


    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    changes.should.eql [{z:new CalculationError(null, 'Sheet runnerA could not be found')}]

  it 'gives an error when function does not exist', ->
    changes = []
    callback = (name, value) -> received = {}; received[name] = value; changes.push received

    runnerA = new ReactiveRunner()
    runnerB = new ReactiveRunner()
    runnerB.onValueChange callback

    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerA', runnerA
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerA, 'x = 10'
    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    changes.should.eql [{z: new CalculationError(null, 'Name y could not be found in sheet runnerA')}]
