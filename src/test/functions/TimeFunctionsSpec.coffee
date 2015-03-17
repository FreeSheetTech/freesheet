should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require '../runtime/ReactiveRunner'
TimeFunctions = require './TimeFunctions'


describe 'TimeFunctions includes', ->

  @timeout 5000

  runner = null
  changes = null

  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)

  callback = (name, value) -> received = {}; received[name] = value; changes.push received

  changesFor = (name) -> changes.filter( (change) -> change.hasOwnProperty(name)).map (change) -> change[name]


  beforeEach ->
    runner = new ReactiveRunner()
    runner.addProvidedFunctions TimeFunctions
    changes = []
    runner.onChange callback

  it 'timeNow - stream of current time as a Date updating every second', (done) ->
    parseUserFunctions 'theTime = now()'
    setTimeout (->
      ticks = changesFor('theTime')
      ticks.length.should.eql(3)
      latestTickMillis = ticks[2].getTime()
      (Date.now() - latestTickMillis).should.be.lessThan(1000)
      done()
    ), 3000