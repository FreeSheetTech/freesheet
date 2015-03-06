should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require '../runtime/ReactiveRunner'
CoreFunctions = require './CoreFunctions'


describe 'CoreFunctions includes', ->

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
    runner.addProvidedTransformFunctions CoreFunctions
    changes = []
    runner.onChange callback

  it 'fromEach - transform input to output simple value', ->
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'pointsFactor = 15; fudgeFactor = 4'
      parseUserFunctions 'scores = fromEach( games, fudgeFactor + in.score * pointsFactor )'

      changesFor('scores').should.eql [[109, 154]]

  it 'fromEach - transform input to output aggregation', ->
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'fudgeFactor = 4'
      parseUserFunctions 'scores = fromEach( games, {time: in.time, originalScore: in.score, adjustedScore: in.score + fudgeFactor} )'

      changesFor('scores').should.eql [[{ time: 21, originalScore: 7, adjustedScore: 11 }, { time: 25, originalScore: 10, adjustedScore: 14}]]

  it 'select - pick inputs where condition is true', ->
      parseUserFunctions 'games = [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]'
      parseUserFunctions 'limit = 10'
      parseUserFunctions 'highScores = select( games, in.score >= limit )'

      changesFor('highScores').should.eql [[ { time: 21, score: 10 }, { time: 28, score: 11} ]]
