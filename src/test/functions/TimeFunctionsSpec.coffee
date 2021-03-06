should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveFunctionRunner = require '../runtime/ReactiveFunctionRunner'
TimeFunctions = require './TimeFunctions'
Period = require './Period'


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
    runner = new ReactiveFunctionRunner()
    runner.addProvidedFunctions TimeFunctions
    changes = []
    runner.onValueChange callback

  it 'now - stream of current time as a Date updating every second', (done) ->
    parseUserFunctions 'theTime = now(10)'
    checkResults = ->
      ticks = changesFor('theTime')
      ticks.length.should.eql(3)
      latestTickMillis = ticks[2].getTime()
      (Date.now() - latestTickMillis).should.be.lessThan(30)
      done()
    setTimeout checkResults, 28

  it 'dateValue - produces Date from ISO format', ->
    parseUserFunctions 'gameEnd = dateValue("2010-03-04 15:16:17")'
    changesFor('gameEnd')[0].should.eql(new Date("2010-03-04 15:16:17"))

  it 'seconds - produces Period', ->
    parseUserFunctions 'gameLength = seconds(30)'
    result = changesFor('gameLength')[0]
    result.should.be.instanceOf(Period)
    result.millis.should.eql(30000)

  it 'asSeconds - Period expressed as seconds', ->
    parseUserFunctions 'gameLength = seconds(30)'
    parseUserFunctions 'secondsRemaining = asSeconds(gameLength)'
    changesFor('secondsRemaining').should.eql([30])

  it 'as Seconds - null for null', ->
    should.equal(TimeFunctions.asSeconds(null), null)