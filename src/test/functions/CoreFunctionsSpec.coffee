should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveFunctionRunner = require '../runtime/ReactiveFunctionRunner'
CoreFunctions = require './CoreFunctions'


describe 'CoreFunctions includes', ->

  runner = null
  changes = null
  values = null

  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)

  callback = (name, value) -> received = {}; received[name] = value; changes.push received
  valueCallback = (name, value) -> received = {}; received[name] = value; values.push received

  changesFor = (name) -> changes.filter( (change) -> change.hasOwnProperty(name)).map (change) -> change[name]
  valuesFor = (name) -> values.filter( (value) -> value.hasOwnProperty(name)).map (value) -> value[name]

  inputs = (items...) -> runner.sendInput 'theInput', i for i in items
  inputs2 = (items...) -> runner.sendInput 'theInput2',  i for i in items
  inputs3 = (items...) -> runner.sendInput 'theInput3',  i for i in items

  beforeEach ->
    runner = new ReactiveFunctionRunner()
    runner.addProvidedFunctions CoreFunctions
    changes = []
    values = []
    runner.onValueChange callback
    runner.onNewValue valueCallback
    parseUserFunctions 'theInput = input; theInput2 = input; theInput3 = input;'

  describe 'withValues', ->

    it 'asNumber - converts text into number', ->
      parseUserFunctions 'num = asNumber("44.5")'
      changesFor('num').should.eql [44.5]


    it 'lines - split text into lines', ->
      parseUserFunctions 'theLines = lines(theInput)'
      inputs '''

              First line
              Second line

              Line 3

             '''
      inputs null
      changesFor('theLines').should.eql [null, ['', 'First line', 'Second line', '', 'Line 3', ''], []]

    it 'nonEmptyLines - split text into lines, ignore empty lines, trim whitespace from others', ->
      parseUserFunctions 'theLines = nonEmptyLines(theInput)'
      inputs '''

                 First line
               Second line

              Line 3

             '''
      changesFor('theLines').should.eql [null, ['First line', 'Second line', 'Line 3']]

    it 'nonEmptyLines - empty list for null input', ->
      parseUserFunctions 'theLines = nonEmptyLines(theInput)'
      inputs null
      changesFor('theLines').should.eql [null, []]

    it 'fromCsvLine - comma or tab-separated text line to trimmed strings or numbers', ->
      parseUserFunctions 'theWords = fromCsvLine("these,are the , 4, words")'
      changesFor('theWords').should.eql [['these', 'are the', 4, 'words']]

    it 'fromCsvLine - null gives empty array', ->
      parseUserFunctions 'noWords = fromCsvLine(none)'
      changesFor('noWords').should.eql [[]]

  describe 'with lists', ->
    it 'item - picks an item at a one-based index', ->
      parseUserFunctions 'theItem = item(2, [30, 40, 50])'
      changesFor('theItem').should.eql [40]

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


  describe 'logical', ->
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

    it 'all', ->
      parseUserFunctions 'collected = all(theInput)'
      inputs 11, 22, 44
      changesFor('collected').should.eql [null, [11], [11, 22], [11, 22, 44]]

    it 'count - number of items', ->
      parseUserFunctions 'itemCount = count( all(theInput) )'
      inputs 11, 22, 33
      changesFor('itemCount').should.eql [ null, 1,2,3]

    it 'sum - add all items', ->
      parseUserFunctions 'itemCount = sum( all(theInput) )'
      inputs 11, 22, 44
      changesFor('itemCount').should.eql [null, 11,33,77]

    it 'first - first of items', ->
      parseUserFunctions 'firstOne = first( all(theInput) )'
      inputs 11, 22, 44
      changesFor('firstOne').should.eql [null, 11]

    it 'sort', ->
      parseUserFunctions 'sorted = sort( all(theInput) )'
      inputs 33,11,44,22
      changesFor('sorted').should.eql [null, [33], [11, 33], [11, 33, 44], [11, 22, 33, 44]]

    it 'sortBy', ->
      parseUserFunctions 'sorted = sortBy( all(theInput), in.a )'
      inputs {a: 33, b: "a"}, {a: 11, b:"b"}, {a:22, b:"c"}
      changesFor('sorted').should.eql [null, [{a: 33, b: "a"}], [{a: 11, b:"b"}, {a: 33, b: "a"}], [{a: 11, b:"b"}, {a:22, b:"c"}, {a: 33, b: "a"}]]

    it 'differentValues', ->
      parseUserFunctions 'distinct = differentValues(all(theInput))'
      inputs 11, 22, 44, 22, 11, 33, 11
      changesFor('distinct').should.eql [ null, [ 11 ], [ 11, 22 ], [ 11, 22, 44 ], [ 11, 22, 44, 33 ] ]

    it 'merge', ->
      parseUserFunctions 'merged = merge(theInput, theInput2)'
      inputs 11, 22
      inputs2 33, 44
      inputs 55
      inputs2 66

      changesFor('merged').should.eql [null, 11, 22, 33, 44, 55, 66]
      valuesFor('merged').should.eql [11, 22, 33, 44, 55, 66]

    it 'onChange - when new value from first stream take current value of second', ->
      parseUserFunctions 'snapshot = onChange(theInput, theInput2)'
      parseUserFunctions 'eachSnapshot = all(snapshot)'
      inputs2 33, 44
      inputs 'a'
      inputs2 55
      inputs 'b'
      inputs 'c'
      inputs 'c'
      inputs2 66, 77
      inputs 'd'
      inputs2 88

      valuesFor('snapshot').should.eql [44, 55, 55, 55, 77]
      changesFor('snapshot').should.eql [null, 44, 55, 77]
      valuesFor('eachSnapshot').should.eql [[44], [44, 55], [44, 55, 55], [44, 55, 55, 55], [44, 55, 55, 55, 77]]
      changesFor('eachSnapshot').should.eql [null, [44], [44, 55], [44, 55, 55], [44, 55, 55, 55], [44, 55, 55, 55, 77]]

    it 'onChange - when new value from first stream take current value of second stream from formula', ->
      parseUserFunctions 'combo = {a: theInput2, b: theInput3}'
      parseUserFunctions 'snapshot = onChange(theInput, combo)'
      inputs null, null, null
      inputs2 33, 44
      inputs3 77
      inputs 'a'

      valuesFor('snapshot').should.eql [null, null, null, {a:44, b:77}]
      changesFor('snapshot').should.eql [null, null, {a:44, b:77}]

    it 'unpackLists - put each element separately into the output', ->
      parseUserFunctions 'itemsIn = theInput'
      parseUserFunctions 'items = unpackLists(itemsIn)'
      parseUserFunctions 'allItems = all(items)'
      parseUserFunctions 'plusOne = items + 1'
      inputs [33, 44, 66], [77], [], [88]

      valuesFor('items').should.eql [66, 77, 88]
