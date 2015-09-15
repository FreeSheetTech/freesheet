should = require 'should'
TextParser = require '../parser/TextParser'
ReactiveFunctionRunner = require './ReactiveFunctionRunner'
RunnerEnvironment = require './RunnerEnvironment'
{CalculationError} = require '../error/Errors'

describe 'RunnerEnvironment', ->

  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (runner, text) -> runner.addUserFunctions parse(text)
  changes = []
  callback = (name, value) -> received = {}; received[name] = value; changes.push received

  beforeEach ->
    changes = []

  it 'allows references from one runner to another', ->
    runnerA = new ReactiveFunctionRunner()
    runnerB = new ReactiveFunctionRunner()
    runnerB.onValueChange callback

    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerA', runnerA
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerA, 'x = 10; y = x * 2'
    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    parseUserFunctions runnerA, 'y = x * 3'

    changes.should.eql [{z:20}, {z: 30}]

  it 'gives an error when sheet does not exist', ->
    runnerB = new ReactiveFunctionRunner()
    runnerB.onValueChange callback


    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    changes.should.eql [{z:new CalculationError('z', 'Sheet runnerA could not be found')}]

  it 'gives an error when function does not exist', ->
    runnerA = new ReactiveFunctionRunner()
    runnerB = new ReactiveFunctionRunner()
    runnerB.onValueChange callback

    runnerEnv = new RunnerEnvironment()
    runnerEnv.add 'runnerA', runnerA
    runnerEnv.add 'runnerB', runnerB

    parseUserFunctions runnerA, 'x = 10'
    parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'

    changes.should.eql [{z: new CalculationError('z', 'Name y could not be found in sheet runnerA')}]

  describe 'renaming a sheet', ->

#    it 'sends an error to existing references and lets it be found under the new name', ->
#      runnerA = new ReactiveFunctionRunner()
#      runnerB = new ReactiveFunctionRunner()
#      runnerB.onValueChange callback
#
#      runnerEnv = new RunnerEnvironment()
#      runnerEnv.add 'runnerA', runnerA
#      runnerEnv.add 'runnerB', runnerB
#
#      parseUserFunctions runnerA, 'y = 10'
#      parseUserFunctions runnerB, 'z = fromSheet("runnerA", "y")'
#
#      runnerEnv.rename 'runnerA', 'runnerQ'
#      parseUserFunctions runnerB, 'z = fromSheet("runnerQ", "y")'
#
#
#      changes.should.eql [{z:10}, {z:new CalculationError(null, 'Sheet runnerA could not be found')}, {z:10}]
