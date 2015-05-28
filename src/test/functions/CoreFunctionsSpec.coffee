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
    runner.addProvidedFunctions CoreFunctions
    changes = []
    runner.onChange callback

  it 'fromEach - transform input to output simple value', ->
    parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
    parseUserFunctions 'pointsFactor = 15; fudgeFactor = 4'
    parseUserFunctions 'scores = fromEach( games, fudgeFactor + in.score * pointsFactor )'

    changesFor('scores').should.eql [[109, 154]]

  it 'fromEach - transform input sequence  to output aggregation sequence', ->
    parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
    parseUserFunctions 'fudgeFactor = 4'
    parseUserFunctions 'scores = fromEach( games, {time: in.time, originalScore: in.score, adjustedScore: in.score + fudgeFactor} )'

    changesFor('scores').should.eql [[{ time: 21, originalScore: 7, adjustedScore: 11 }, { time: 25, originalScore: 10, adjustedScore: 14}]]

  it 'fromEach - transform input sequence to output single value sequence', ->
    parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
    parseUserFunctions 'fudgeFactor = 4'
    parseUserFunctions 'scores = fromEach( games, in.score + fudgeFactor )'

    changesFor('scores').should.eql [[11, 14]]

  it 'select - pick inputs where condition is true', ->
    parseUserFunctions 'games = [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]'
    parseUserFunctions 'limit = 10'
    parseUserFunctions 'highScores = select( games, in.score >= limit )'

    changesFor('highScores').should.eql [[ { time: 21, score: 10 }, { time: 28, score: 11} ]]

  it 'shuffle - list in random order', ->
    parseUserFunctions 'items = [ 1,2,3,4,5,6,7,8,9,10 ]'
    parseUserFunctions 'shuffledItems = shuffle( items )'

    result = changesFor('shuffledItems')[0]

    result.length.should.eql 10
    result.should.not.eql [ 1,2,3,4,5,6,7,8,9,10 ]

  it 'count - items in a list', ->
    parseUserFunctions 'items = [ 1,2,3,4,5,6 ]'
    parseUserFunctions 'itemCount = count( items )'
    changesFor('itemCount').should.eql [6]

  it 'sum - add all items in a list', ->
    parseUserFunctions 'items = [ 1,2,3,4,5,6 ]'
    parseUserFunctions 'itemTotal = sum( items )'
    changesFor('itemTotal').should.eql [21]

  it 'ifElse - boolean chooses one of two other expressions', ->
    parseUserFunctions 'score = 10; passMark = 20'
    parseUserFunctions 'result = ifElse(score >= passMark, "Pass", "Fail")'
    changesFor('result').should.eql ['Fail']
    parseUserFunctions 'score = 30'
    changesFor('result').should.eql ['Fail', 'Pass']

   it 'and - boolean operator', ->
     parseUserFunctions 'resultTrue = and(1 == 1, 4 > 3) '
     parseUserFunctions 'resultFalse = and(1 == 1, 4 < 3) '
     changesFor('resultTrue').should.eql [true]
     changesFor('resultFalse').should.eql [false]

   it 'or - boolean operator', ->
     parseUserFunctions 'resultFalse = or(1 > 1, 4 < 3) '
     parseUserFunctions 'resultTrue = or(1 == 1, 4 < 3) '
     changesFor('resultFalse').should.eql [false]
     changesFor('resultTrue').should.eql [true]

