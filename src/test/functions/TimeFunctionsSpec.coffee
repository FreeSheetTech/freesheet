should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require '../runtime/ReactiveRunner'
TimeFunctions = require './TimeFunctions'


describe 'TimeFunctions includes', ->

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

  it 'timeNow - current time as a Date', ->
    parseUserFunctions 'theTime = timeNow()'
    result = changesFor('theTime')[0]
    resultMillis = result.getTime()
    (Date.now() - resultMillis).should.be.lessThan(500)
