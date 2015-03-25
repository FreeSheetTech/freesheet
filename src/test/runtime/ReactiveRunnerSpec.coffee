should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require './ReactiveRunner'
TimeFunctions = require '../functions/TimeFunctions'
Period = require '../functions/Period'

describe 'ReactiveRunner runs', ->

  runner = null
  changes = null
  namedChanges = null
  inputSubj = null

  apply = (funcOrValue, x) -> if typeof funcOrValue == 'function' then funcOrValue(x) else funcOrValue
  fromEachFunction = (seq, func) -> (apply(func, x) for x in seq)
  selectFunction = (seq, func) -> (x for x in seq when apply(func, x))

  providedFunctions = (functionMap) -> runner.addProvidedFunctions functionMap
  providedValueFunctions = (functionMap) -> runner.addProvidedValueFunctions functionMap
  providedStreams = (streamMap) -> runner.addProvidedStreams streamMap
  providedTransformFunctions = (functionMap) -> runner.addProvidedTransformFunctions functionMap
  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)

  callback = (name, value) -> received = {}; received[name] = value; changes.push received
  namedCallback = (name, value) -> received = {}; received[name] = value; namedChanges.push received

  changesFor = (name) -> changes.filter( (change) -> change.hasOwnProperty(name)).map (change) -> change[name]

  observeNamedChanges = (name) -> runner.onChange namedCallback, name

  beforeEach ->
    runner = new ReactiveRunner()
    changes = []
    namedChanges = []
    runner.onChange callback
    inputSubj = new Rx.Subject()
    providedFunctions TimeFunctions
    providedTransformFunctions
      fromEach: fromEachFunction
      select: selectFunction


  describe 'runs expressions', ->
    it 'all arithmetic operations on numbers', ->
      parseUserFunctions 'a=100'
      parseUserFunctions '  p=a+2  '
      parseUserFunctions 'q = 150   -  a  '
      parseUserFunctions 'r =1200 / a'
      parseUserFunctions 's= a * 5.2'

      changes.should.eql [{a: 100}, {p: 102}, {q: 50}, {r :12}, {s: 520}]

    it 'subtraction of two Dates', ->
      parseUserFunctions 'd1=dateValue("2014-02-03 12:00:20")'
      parseUserFunctions 'd2=dateValue("2014-02-03 12:00:30")'
      parseUserFunctions 'diff = d2 - d1'

      changesFor('diff').should.eql [Period.seconds(10)]

    it 'addition and subtraction of Date and time period', ->
      parseUserFunctions 'd1=dateValue("2014-02-03 12:00:20")'
      parseUserFunctions 'p10 = seconds(10)'
      parseUserFunctions 'timeLater = d1 + p10'
      parseUserFunctions 'timeEarlier = d1 - p10'

      changesFor('timeLater').should.eql [new Date("2014-02-03 12:00:30")]
      changesFor('timeEarlier').should.eql [new Date("2014-02-03 12:00:10")]

    it 'addition and subtraction of period and period', ->
      parseUserFunctions 'p15 = seconds(15)'
      parseUserFunctions 'p25 = seconds(25)'
      parseUserFunctions 'totalPeriod = p25 + p15'
      parseUserFunctions 'diff = p25 - p15'

      changesFor('totalPeriod').should.eql [Period.seconds 40]
      changesFor('diff').should.eql [Period.seconds 10]

    it 'all comparison operations on numbers', ->
      parseUserFunctions 'a = 100 > 100'
      parseUserFunctions 'b = 100 < 101'
      parseUserFunctions 'c = 101 >= 100'
      parseUserFunctions 'd = 101 <= 100'
      parseUserFunctions 'e = 101 == 100'
      parseUserFunctions 'f = 101 <> 100'
      changes.should.eql [{a: false}, {b: true}, {c: true}, {d: false}, {e: false}, {f:true}]

    it 'all comparison operations on dates', ->
      parseUserFunctions 'd1=dateValue("2014-02-03 12:00:20")'
      parseUserFunctions 'd2=dateValue("2014-02-03 12:00:30")'
      parseUserFunctions 'a = d1 > d1'
      parseUserFunctions 'b = d1 < d2'
      parseUserFunctions 'c = d2 >= d1'
      parseUserFunctions 'd = d2 <= d1'
      parseUserFunctions 'e = d2 == d1'
      parseUserFunctions 'f = d2 <> d1'
      changes[2..].should.eql [{a: false}, {b: true}, {c: true}, {d: false}, {e: false}, {f:true}]

    it 'concatenates strings', ->
      parseUserFunctions 'a = "The A"'
      parseUserFunctions 'aa = a + 10 + " times"'

      changes.should.eql [{a: 'The A'}, {aa: 'The A10 times'}]

    it 'creates objects for aggregation expressions using constants, function calls and operations', ->
      parseUserFunctions 'x = 20; obj = {a: 10, b: "Fred", c: x, d: x + 30}'
      changes.should.eql [{x: 20}, {obj: {a: 10, b: "Fred", c: 20, d: 50}}]

    it 'creates arrays for sequence expressions using constants, function calls and operations', ->
      parseUserFunctions 'x = 20; seq = [10, "Fred", x, x + 30]'
      changes.should.eql [{x: 20}, {seq: [10, "Fred", 20, 50] }]

    it 'selects from aggregations', ->
      parseUserFunctions 'x = 20; obj = {a: 10, d: x + 30}'
      parseUserFunctions 'aa = obj.a; dd = obj . d '
      changes.should.eql [{x: 20}, {obj: {a: 10, d: 50}}, {aa: 10}, {dd: 50}]


    it 'function with no args returning constant', ->
      parseUserFunctions ''' theAs = "aaaAAA" '''
      changes.should.eql [{theAs: "aaaAAA"}]

    it 'function with no args returning constant calculated addition expression', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3 '''
      changes.should.eql [{twelvePlusThree: 15}]

    it 'function with no args returning another function with no args', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3; five = twelvePlusThree / 3 '''
      changesFor('five').should.eql [5]

    it 'function using a provided value function with no args', ->
      providedValueFunctions { theInput: -> 20 }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]

    it 'function using a provided value function with some args', ->
      providedValueFunctions { double: (x) -> x * 2 }
      parseUserFunctions '''doubleMinusTwo = double(15) - 2 '''
      changesFor('doubleMinusTwo').should.eql [28]

    it 'function using a user function with name overriding a built-in function', ->
      providedValueFunctions { theInput: -> 20 }
      parseUserFunctions '''theInput = 30'''
      parseUserFunctions '''inputMinusTwo = theInput - 2 '''
      changesFor('inputMinusTwo').should.eql [28]

    it 'complex and bracketed expressions with correct precedence', ->
      parseUserFunctions 'a = 10'
      parseUserFunctions 'b = 20'
      parseUserFunctions 'c = 5'

      parseUserFunctions 'q = a + c * 3 - (a + b) / 10'
      changes.should.eql [{a: 10}, {b: 20}, {c: 5}, {q: 22}]

    it 'function calls with other expressions as arguments to provided value functions with arguments', ->
      parseUserFunctions 'a = 10'
      parseUserFunctions 'b = 20'
      parseUserFunctions 'c = 5'
      providedValueFunctions
        addOne: (a) -> a + 1
        getTheAnswer: (a, b, c) -> a + b - c

      parseUserFunctions 'q = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )'

      changes.should.eql [{a: 10}, {b: 20}, {c: 5}, {q: 122}]

  describe 'expressions as function arguments with sequences', ->
    it 'transforms all elements of a sequence to a literal', ->
      parseUserFunctions 'games = [ { time: 21, score: 70 }, { time: 25, score: 130} ]'
      parseUserFunctions 'points = fromEach( games, 10 )'

      changes.should.eql [{games: [ { time: 21, score: 70 }, { time: 25, score: 130} ]}, {points: [10, 10]}]

    it 'transforms all elements of a sequence to a named value even when value changes', ->
      parseUserFunctions 'games = [ { time: 21, score: 70 }, { time: 25, score: 130} ]'
      parseUserFunctions 'pointsFactor = 15'
      parseUserFunctions 'points = fromEach( games, pointsFactor )'
      parseUserFunctions 'pointsFactor = 17'

      changes.should.eql [{games: [ { time: 21, score: 70 }, { time: 25, score: 130} ]}, {pointsFactor: 15}, {points: [15, 15]},
                            {pointsFactor: 17}, {points: [17, 17]}]

    it 'transforms all elements of a sequence to a formula including two named values', ->
      parseUserFunctions 'games = [ { time: 21, score: 70 }, { time: 25, score: 130} ]'
      parseUserFunctions 'pointsFactor = 15; wowFactor = 5'
      parseUserFunctions 'points = fromEach( games, pointsFactor * wowFactor + 50 )'
      parseUserFunctions 'wowFactor = 10'

      changes.should.eql [{games: [ { time: 21, score: 70 }, { time: 25, score: 130} ]},
                            {pointsFactor: 15}, {wowFactor: 5}, {points: [125, 125]},
                            {wowFactor: 10}, {points: [200, 200]}]

    it 'transforms all elements of a sequence to a value from the input', ->
      parseUserFunctions 'games = [ { time: 21, score: 70 }, { time: 25, score: 130} ]'
      parseUserFunctions 'scores = fromEach( games, in.score )'

      changes.should.eql [{games: [ { time: 21, score: 70 }, { time: 25, score: 130} ]}, {scores: [70, 130]}]

    it 'transforms all elements of a sequence to a formula including a value from the input and named values', ->
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'pointsFactor = 15; fudgeFactor = 4'
      parseUserFunctions 'scores = fromEach( games, fudgeFactor + in.score * pointsFactor )'

      changes.should.eql [{games: [ { time: 21, score: 7 }, { time: 25, score: 10} ]}, {pointsFactor: 15}, {fudgeFactor: 4}, {scores: [109, 154]}]

    it 'transforms all elements of a sequence to a formula including a provided stream and values change for each value in the stream', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, in.score + theInput() )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [null, [27, 30], [37, 40]]

    it 'transforms all elements of a sequence to a formula using a provided stream of a function with literal arguments and values change for each value in the stream', ->
      providedStreams
        adjust: inputSubj.map (ff) -> (adjustment) -> ff + adjustment
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, in.score + adjust(5) )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [null, [32, 35], [42, 45]]    #first result is zero because adjust function not generated until first inputSubj value

    it 'transforms all elements of a sequence to a formula using a provided stream of a function with arguments from input and values change for each value in the stream', ->
      providedStreams
        adjust:  inputSubj.startWith(0).map (ff) -> (adjustment) -> ff + adjustment
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, adjust(in.score) )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [[7, 10], [27, 30], [37, 40]]  #first result is unadjusted values because adjust function starts with 0

    it 'filters elements of a sequence using a formula including a value from the input and named values', ->
      parseUserFunctions 'games = [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]'
      parseUserFunctions 'pointsFactor = 6; fudgeFactor = 4'
      parseUserFunctions 'highScores = select( games, in.score >= pointsFactor + fudgeFactor )'

      changes.should.eql [{games: [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]},
                          {pointsFactor: 6}, {fudgeFactor: 4},
                          {highScores: [{ time: 21, score: 10 }, { time: 28, score: 11}]}]



  describe 'updates dependent expressions and notifies changes', ->
    it 'to a constant value formula when it is set and changed', ->
      parseUserFunctions 'price = 22.5; tax_rate = 0.2'
      parseUserFunctions 'price = 33.5'
      changes.should.eql [{price:22.5}, {'tax_rate':0.2}, {price: 33.5}]

    it 'to a function set after it is observed', ->
      observeNamedChanges 'price'

      parseUserFunctions 'price = 22.5; tax_rate = 0.2'
      parseUserFunctions 'price = 33.5'

      namedChanges.should.eql [{price:null}, {price:22.5}, {price: 33.5}]
      changes.should.eql [{price:null}, {price:22.5}, {'tax_rate':0.2}, {price: 33.5}]

    it 'to a function that uses an event stream via a provided function', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      inputSubj.onNext 'Aarhon'
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:'Zorgon'}]

    it 'of a function that calls a function that uses an event stream via a provided function', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'number = theInput(); plusOne = number + 1'
      inputSubj.onNext 10
      inputSubj.onNext 20

      changes.should.eql [{number:null}, {plusOne:1}, {number:10}, {plusOne:11}, {number:20}, {plusOne:21}]


    it 'to a function that uses an event stream via a provided function with arguments', ->
      providedStreams inputValueWithSuffix: inputSubj.map (iv) -> (p, s) -> p + iv + s

      parseUserFunctions 'aliens = inputValueWithSuffix("some ", " stuff")'
      inputSubj.onNext 'Aarhon'
      observeNamedChanges 'aliens'

      inputSubj.onNext 'Zorgon'

      namedChanges.should.eql [{aliens: 'some Aarhon stuff'}, {aliens: 'some Zorgon stuff'}]

    it 'when referenced functions defined before', ->
      parseUserFunctions 'materials = 35; labour = 25'
      parseUserFunctions 'total = materials + labour'

      changes.should.eql [{materials: 35}, {labour:25}, {total: 60}]

    it 'when referenced functions defined after', ->
      parseUserFunctions 'total = materials + labour'
      parseUserFunctions 'materials = 35; labour = 25'

      changes.should.eql [{ materials: null }, {labour: null }, {total: 0 }, {materials: 35 }, {total: 35 }, {labour: 25 }, {total: 60 }]

    it 'adds two changing values in formula set afterwards', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'materials = 35'
      parseUserFunctions 'labour = theInput()'
      parseUserFunctions 'total = materials + labour'

      inputSubj.onNext 25
      parseUserFunctions 'materials = 50'

      changes.should.eql [{materials: 35}, {labour:null}, {total: 35}, {labour:25}, {total: 60}, {materials: 50}, {total: 75}]


    it 'adds two changing values in function set in between', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'materials = 35'
      parseUserFunctions 'total = materials + labour'
      parseUserFunctions 'labour = theInput()'

      inputSubj.onNext 25

      changes.should.eql [{materials: 35}, {labour:null}, {total: 35}, {labour:25}, {total: 60}]

    it 'on individual named value including initial value', ->

      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aaa = 10'

      observeNamedChanges 'aaa'
      observeNamedChanges 'xxx'
      observeNamedChanges 'bbb'

      parseUserFunctions 'bbb = theInput()'
      inputSubj.onNext 'value of bbb'

      namedChanges.should.eql [{aaa: 10}, {xxx: null}, {bbb: null}, {bbb: 'value of bbb'}]



#  it 'function with one arg which is a literal', ->
#    scriptFunctions = parse '''addFive(n) = n + 5; total = addFive(14)'''
#    runner = new ReactiveRunner({}, scriptFunctions)
#
#    subject = runner.output 'total'
#    valueReceived = null
#    subject.subscribe (value) -> valueReceived = value
#
#    valueReceived.should.eql 19
#
#  it 'function with one arg which is a constant expression', ->
#    scriptFunctions = parse '''twelvePlusThree = 12 + 3; addFive(n) = n + 5; total = addFive(twelvePlusThree)'''
#    runner = new ReactiveRunner({}, scriptFunctions)
#
#    subject = runner.output 'total'
#    valueReceived = null
#    subject.subscribe (value) -> valueReceived = value
#
#    valueReceived.should.eql 20
