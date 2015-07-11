should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require '../runtime/ReactiveRunner'
CoreFunctions = require './CoreFunctions'


describe 'CoreFunctions includes', ->

  runner = null
  changes = null
  inputSubj = null


  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)

  callback = (name, value) -> received = {}; received[name] = value; changes.push received

  changesFor = (name) -> changes.filter( (change) -> change.hasOwnProperty(name)).map (change) -> change[name]

  inputs = (items...) -> inputSubj.onNext i for i in items

  beforeEach ->
    runner = new ReactiveRunner()
    runner.addProvidedFunctions CoreFunctions
    changes = []
    runner.onValueChange callback
    inputSubj = new Rx.Subject()
    runner.addProvidedStream 'theInput', inputSubj


  describe 'with lists', ->
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

    it 'count - number of items', ->
      parseUserFunctions 'items = [ 1,2,3,4,5,6 ]'
      parseUserFunctions 'itemCount = count( items )'
      changesFor('itemCount').should.eql [6]

    it 'sum - add all items in a list', ->
      parseUserFunctions 'items = [ 1,2,3,4,5,6 ]'
      parseUserFunctions 'itemTotal = sum( items )'
      changesFor('itemTotal').should.eql [21]

    it 'first - first of items', ->
      parseUserFunctions 'items = [ 11,22,33]'
      parseUserFunctions 'firstItem = first( items )'
      changesFor('firstItem').should.eql [11]

    it 'collect - although pointless with a list', ->
      parseUserFunctions 'items = [ 33,11,44,22]'
      parseUserFunctions 'collected = collect( items )'
      changesFor('collected').should.eql [[33,11,44,22]]

    it 'differentValues', ->
      parseUserFunctions 'items = [ 11, 22, 44, 22, 11, 33, 11]'
      parseUserFunctions 'distinct = differentValues( items )'
      changesFor('distinct').should.eql [[11, 22, 44, 33]]

    it 'sort', ->
      parseUserFunctions 'items = [ 33,11,44,22]'
      parseUserFunctions 'sorted = sort( items )'
      changesFor('sorted').should.eql [[11, 22, 33, 44]]

    it 'sortBy', ->
      parseUserFunctions 'items = [ {a: 33, b: "a"}, {a: 11, b:"b"}, {a:22, b:"c"}]'
      parseUserFunctions 'sorted = sortBy( items, in.a )'
      changesFor('sorted').should.eql [[{a: 11, b:"b"}, {a:22, b:"c"}, {a: 33, b: "a"}]]

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

  describe 'with streams', ->

    it 'count - number of items', ->
      parseUserFunctions 'itemCount = countOver( theInput )'
      inputs 11, 22, 33
      changesFor('itemCount').should.eql [null, 1,2,3]

    it 'sum - add all items', ->
      parseUserFunctions 'itemCount = sumOver( theInput )'
      inputs 11, 22, 44
      changesFor('itemCount').should.eql [null, 11,33,77]

    it 'first - first of items', ->
      parseUserFunctions 'itemCount = firstOver( theInput )'
      inputs 11, 22, 44
      changesFor('itemCount').should.eql [null, 11]

    it 'collect', ->
      parseUserFunctions 'collected = collectOver( theInput )'
      inputs 11, 22, 44
      changesFor('collected').should.eql [null, [11], [11, 22], [11, 22, 44]]

    it 'sort', ->
      parseUserFunctions 'sorted = sortOver( theInput )'
      inputs 33,11,44,22
      changesFor('sorted').should.eql [null, [33], [11, 33], [11, 33, 44], [11, 22, 33, 44]]

    it 'sortBy', ->
      parseUserFunctions 'sorted = sortByOver( theInput, in.a )'
      inputs {a: 33, b: "a"}, {a: 11, b:"b"}, {a:22, b:"c"}
      changesFor('sorted').should.eql [null, [{a: 33, b: "a"}], [{a: 11, b:"b"}, {a: 33, b: "a"}], [{a: 11, b:"b"}, {a:22, b:"c"}, {a: 33, b: "a"}]]

    it 'differentValues', ->
      parseUserFunctions 'distinct = differentValuesOver(theInput)'
      inputs 11, 22, 44, 22, 11, 33, 11
      changesFor('distinct').should.eql [null, 11, 22, 44, 33]

    it 'merge', ->
      input2Subj = new Rx.Subject()
      runner.addProvidedStream 'theInput2', input2Subj
      inputs2 = (items...) -> input2Subj.onNext i for i in items

      parseUserFunctions 'merged = merge(theInput, theInput2)'
      inputs 11, 22
      inputs2 33, 44
      inputs 55
      inputs2 66

      changesFor('merged').should.eql [null, 11, 22, 33, 44, 55, 66]

    it 'onChange - when changed value from first stream take value of second', ->
      input2Subj = new Rx.Subject()
      runner.addProvidedStream 'theInput2', input2Subj
      inputs2 = (items...) -> input2Subj.onNext i for i in items

      parseUserFunctions 'snapshot = onChange(theInput, theInput2)'
      inputs2 33, 44
      inputs 'a'
      inputs2 55
      inputs 'b'
      inputs 'c'
      inputs 'c'
      inputs2 66, 77
      inputs 'd'
      inputs2 88

      changesFor('snapshot').should.eql [null, 44, 55, 55, 77]



