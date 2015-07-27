should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
SheetRunner = require './SheetRunner'
TimeFunctions = require '../functions/TimeFunctions'
Period = require '../functions/Period'
{CalculationError, FunctionError} = require '../error/Errors'

describe 'SheetRunner runs', ->

  runner = null
  changes = null
  bufferedChanges = null
  namedChanges = null
  inputSubj = null

  apply = (funcOrValue, x) -> if typeof funcOrValue == 'function' then funcOrValue(x) else funcOrValue
  fromEachFunction = (s, func) -> s.map (x) -> apply(func, x)
  selectFunction = (s, func) -> s.filter (x) -> apply(func, x)

  providedFunctions = (functionMap) -> runner.addProvidedFunctions functionMap
  providedStreams = (streamMap) -> runner.addProvidedStreams streamMap
  providedAggregateFunctions = (functionMap) -> runner.addProvidedAggregateFunctions functionMap
  providedSequenceFunctions = (functionMap) -> runner.addProvidedSequenceFunctions functionMap
  providedStreamFunctions = (functionMap) -> runner.addProvidedStreamFunctions functionMap
  providedStreamReturnFunctions = (functionMap) -> runner.addProvidedStreamReturnFunctions functionMap
  providedTransformFunctions = (functionMap) -> runner.addProvidedTransformFunctions functionMap
  parse = (text) ->
    map = new TextParser(text).functionDefinitionMap()
    (v for k, v of map)
  parseUserFunctions = (text) -> runner.addUserFunctions parse(text)
  removeUserFunction = (name) -> runner.removeUserFunction name
  sendInput = (name, value) -> runner.sendInput name, value

  callback = (name, value) -> received = {}; received[name] = value; changes.push received
  bufferedCallback = (name, value) -> received = {}; received[name] = value; bufferedChanges.push received
  namedCallback = (name, value) -> received = {}; received[name] = value; namedChanges.push received

  inputs = (items...) -> sendInputs 'theInput', items...
  sendInputs = (name, items...) -> runner.sendInput name, i for i in items
  changesFor = (name) -> changes.filter( (change) -> change.hasOwnProperty(name)).map (change) -> change[name]

  observeNamedChanges = (name) -> runner.onValueChange namedCallback, name
  unknown = (name) -> error(name, 'Unknown name')
  error = (name, msg) -> new CalculationError(name, msg)
  fnError = (name, msg) -> new FunctionError(name, msg)

  beforeEach ->
    runner = new SheetRunner()
    parseUserFunctions 'theInput = input'

    changes = []
    bufferedChanges = []
    namedChanges = []
    runner.onValueChange callback
    runner.onBufferedValueChange bufferedCallback
    inputSubj = new Rx.Subject()

    providedFunctions TimeFunctions
    providedTransformFunctions
      fromEach: fromEachFunction
      select: selectFunction


  describe 'runs expressions', ->
    it 'constant values', ->
      parseUserFunctions 'a=100'

      changes.should.eql [{a: 100}]

    it 'all arithmetic operations on numbers', ->
      parseUserFunctions 'a=100'
      parseUserFunctions '  p=a+2  '
      parseUserFunctions 'q = 150   -  a  '
      parseUserFunctions 'r =1200 / a'
      parseUserFunctions 's= a * 5.2'

      changes.should.eql [{a: 100}, {p: 102}, {q: 50}, {r :12}, {s: 520}]

    it 'operations with null', ->
      parseUserFunctions 'a=100 + none'
      parseUserFunctions 'b = none'
      parseUserFunctions 'c = a <> none'
      parseUserFunctions 'c = a == none'
      parseUserFunctions 'c = b == none'
      parseUserFunctions 'c = b <> none'

      changes.should.eql [{a: 100}, {b: null}, {c: true}, {c: false}, {c: true}, {c: false}]

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

    it 'logical operations with comparisons', ->
      parseUserFunctions 'a = 100 > 100'
      parseUserFunctions 'b = 100 < 101'
      parseUserFunctions 'c = 101 >= 100'
      parseUserFunctions 'x = a or b'
      parseUserFunctions 'x = a and b'
      parseUserFunctions 'x = b and c'
      parseUserFunctions 'x = false'
      parseUserFunctions 'x = a or b and c or false'
      changesFor('x').should.eql [true, false, true, false, true]

    it 'concatenates strings', ->
      parseUserFunctions 'a = "The A"'
      parseUserFunctions 'aa = a + 10 + " times"'

      changes.should.eql [{a: 'The A'}, {aa: 'The A10 times'}]

    it 'merges aggregates', ->
      parseUserFunctions 'a = {a: 10}'
      parseUserFunctions 'b = a + {b: 20}'

      changes.should.eql [{a: {a: 10}}, {b: {a: 10, b: 20}}]

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
      runner.hasUserFunction('theAs').should.eql false
      parseUserFunctions ''' theAs = "aaaAAA" '''
      runner.hasUserFunction('theAs').should.eql true
      changes.should.eql [{theAs: "aaaAAA"}]

    it 'function with no args returning constant calculated addition expression', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3 '''
      changes.should.eql [{twelvePlusThree: 15}]

    it 'function with no args returning another function with no args', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3; five = twelvePlusThree / 3 '''
      changesFor('five').should.eql [5]

    it 'function using a provided value function with no args', ->
      ((functionMap) -> providedFunctions functionMap) { theInput: -> 20 }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]

    it 'function using a provided value function with some args', ->
      ((functionMap) -> providedFunctions functionMap) { double: (x) -> x * 2 }
      parseUserFunctions '''doubleMinusTwo = double(15) - 2 '''
      changesFor('doubleMinusTwo').should.eql [28]

    it 'function using a user function with name overriding a built-in function', ->
      ((functionMap) -> providedFunctions functionMap) { theInput: -> 20 }
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
      ((functionMap) -> providedFunctions functionMap)
        addOne: (a) -> a + 1
        getTheAnswer: (a, b, c) -> a + b - c

      parseUserFunctions 'q = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )'

      changes.should.eql [{a: 10}, {b: 20}, {c: 5}, {q: 122}]

  describe 'functions with arguments', ->

    it 'can be defined and evaluated with one literal argument', ->
      parseUserFunctions 'addFive(n) = n + 5; total = addFive(14)'
      changesFor('total').should.eql [19]

    it 'can be called with two other named values', ->
      parseUserFunctions 'a = 4; b = 5'
      parseUserFunctions 'addAndSquare(p, q) = (p + q) * (p + q); result = addAndSquare(a, b)'
      changesFor('result').should.eql [81]

    it 'can be called with another function with arguments', ->
      parseUserFunctions 'addFive(n) = n + 5; addTen(n) = n + 10'
      parseUserFunctions 'result = addFive(addTen(20))'
      changesFor('result').should.eql [35]

    it 'can use a named value on its own in the definition', ->
      parseUserFunctions 'a = 4'
      parseUserFunctions 'sameAsA(p) = a; result = sameAsA(9)'
      changesFor('result').should.eql [4]

    it 'can use an input on its own in the definition', ->
      parseUserFunctions 'a = input'
      parseUserFunctions 'inputA(p) = a; result = inputA(9)'
      sendInput 'a', "forty-two"
      changesFor('result').should.eql [null, "forty-two"]

    it 'can use an input in an expression in the definition', ->
      parseUserFunctions 'a = input'
      parseUserFunctions 'aPlus(p) = a + p; result = aPlus(9)'
      sendInput 'a', 10
      changesFor('result').should.eql [9, 19]

    it 'can use provided functions in the definition', ->
      providedFunctions
        square: (x) -> x * x
      parseUserFunctions 'addFiveToSquare(p) = 5 + square(p); result = addFiveToSquare(9)'
      changesFor('result').should.eql [86]

    it 'can use user-defined functions in the definition', ->
      parseUserFunctions 'addFive(n) = n + 5; addTen(n) = addFive(addFive(n))'
      parseUserFunctions 'result = addTen(20)'
      changesFor('result').should.eql [30]

    it 'can be called with two nested function calls', ->
      providedFunctions {square: (x) -> x * x }
      parseUserFunctions 'addFive(n) = n + 5;'
      parseUserFunctions 'addTenToSquare(p) = addFive(addFive(square(p))); result = addTenToSquare(9)'
      changesFor('result').should.eql [91]

    it 'change when values they use change', ->
      parseUserFunctions 'a = 4'
      parseUserFunctions 'addA(p) = a + p; result = addA(10)'
      parseUserFunctions 'a = 5'

      changesFor('result').should.eql [14, 15]

    it 'change when values in functions they use change', ->
      parseUserFunctions 'a = 4'
      parseUserFunctions 'addA(p) = a + p; addAPlus10(p) = addA(p) + 10; result = addAPlus10(10)'
      parseUserFunctions 'a = 5'

      changesFor('result').should.eql [24, 25]

    it.skip 'can be defined with an expression using a stream return function', ->
      providedStreamReturnFunctions
        widgetFactor: (a) -> inputSubj.map (x) -> x + a
      parseUserFunctions 'wf(p) = widgetFactor(5) + p'
      parseUserFunctions 'result = wf(3)'

      inputSubj.onNext 20
      inputSubj.onNext 30
      inputSubj.onNext 40

      changesFor("result").should.eql [null, 28, 38, 48]

    it.skip 'can NOT be defined with only a stream return function', ->
      providedStreamReturnFunctions
        widgetFactor: (a) -> inputSubj.map (x) -> x + a
      parseUserFunctions 'wf(p) = widgetFactor(p)'
      parseUserFunctions 'result = wf(3)'

      inputSubj.onNext 20
      inputSubj.onNext 30
      inputSubj.onNext 40

      changesFor("result").should.eql [fnError("wf", "Sorry - this formula cannot be used")]


  describe 'inputs', ->

    it 'create a named input when add user function with input expr', ->
      parseUserFunctions 'in1 = input'
      parseUserFunctions 'in2 = input'

      runner.getInputs().should.eql ['theInput', 'in1', 'in2']
      changes.should.eql [{in1: null}, {in2: null}]

    it 'update other values when a new input sent', ->
      parseUserFunctions 'materials = input; labour = input; taxRate = 0.2'
      parseUserFunctions 'total = (materials + labour) * (1 + taxRate)'

      sendInput 'materials', 100
      sendInput 'labour', 200

      changes.should.eql [{materials: null}, {labour:null}, {taxRate: 0.2}, {total: 0}, {materials: 100}, {total: 120}, {labour: 200}, {total: 360}]

    it 'send a null when a formula is updated to an input', ->
      parseUserFunctions 'in1 = 20'
      parseUserFunctions 'in1 = input'

      runner.getInputs().should.eql ['theInput', 'in1']
      changes.should.eql [{in1: 20}, {in1: null}]

#    it 'update other values when a debug input sent to any named value', ->
#      parseUserFunctions 'materials = none; taxRate = 0.2'
#      parseUserFunctions 'total = materials * (1 + taxRate)'
#
#      runner.sendDebugInput 'materials', 100
#      runner.sendDebugInput 'taxRate', 0.3
#
#      changes.should.eql [{materials: null}, {taxRate: 0.2}, {total: 0}, {materials: 100}, {total: 120}, {taxRate: 0.3}, {total: 130}]

    it 'throw exception for inputs to unknown subjects', ->
      parseUserFunctions 'materials = input; taxRate = 0.2'

      (-> sendInput 'taxRate', 10).should.throw /Unknown input name/
      (-> runner.sendDebugInput 'unknown', 10).should.throw /Unknown name/

  describe 'errors in expression evaluation', ->

    it 'create a subtype of Error', ->
      e = new CalculationError("fn1", "it went wrong")
      e.functionName.should.eql 'fn1'
      e.message.should.eql 'it went wrong'
      e.should.be.an.instanceof Error

    it 'calling unknown function', ->
      parseUserFunctions 'a = 10'
      parseUserFunctions 'num = a + ddd(5)'
      changes.should.eql [{a: 10}, {num: unknown 'ddd'}]

    it 'divide by zero', ->
      parseUserFunctions 'a = 10'
      parseUserFunctions 'b = 0'
      parseUserFunctions 'num = a / b'
      changes.should.eql [{a: 10}, {b: 0}, {num: error 'num', 'Divide by zero'}]

    it 'invalid calculation', ->
      parseUserFunctions 'a = 10'
      parseUserFunctions 'num = a - "xxx"'
      changes.should.eql [{a: 10}, {num: error 'num', 'Invalid values in calculation'}]

    it 'invalid calculation in literal expression', ->
      parseUserFunctions 'num = 10 - "xxx"'
      changes.should.eql [{num: error 'num', 'Invalid values in calculation'}]

    it.skip 'direct circular expression', ->
      parseUserFunctions 'x = 10'
      parseUserFunctions 'x = x.y'
      changes.should.eql [{x:10}, {x: error 'x', 'Formula uses itself' }]

    it.skip 'indirect circular expression', ->
      parseUserFunctions 'y = 10'
      parseUserFunctions 'x = y'
      parseUserFunctions 'y = x'
      changes.should.eql [{y:10}, {x:10}, {y: error 'y', 'Formula uses itself through another formula' }, {x: error 'y', 'Formula uses itself through another formula' }]

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

    it.skip 'transforms all elements of a sequence to a formula including a provided stream and values change for each value in the stream', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, in.score + theInput() )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [null, [27, 30], [37, 40]]

    it.skip 'transforms all elements of a sequence to a formula using a provided stream of a function with literal arguments and values change for each value in the stream', ->
      providedStreams
        adjust: inputSubj.map (ff) -> (adjustment) -> ff + adjustment
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, in.score + adjust(5) )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [null, [32, 35], [42, 45]]    #first result is zero because adjust function not generated until first inputSubj value

    it.skip 'transforms all elements of a sequence to a formula using a provided stream of a function with arguments from input and values change for each value in the stream', ->
      providedStreams
        adjust:  inputSubj.startWith(0).map (ff) -> (adjustment) -> ff + adjustment
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, adjust(in.score) )'

      inputSubj.onNext 20
      inputSubj.onNext 30

      changesFor("scores").should.eql [[7, 10], [27, 30], [37, 40]]  #first result is unadjusted values because adjust function starts with 0

    it 'transforms all elements of a sequence to an aggregate using input values and names from the output aggregate', ->
      parseUserFunctions 'games = [ { time: 21, score: 7 }, { time: 25, score: 10} ]'
      parseUserFunctions 'scores = fromEach( games, {basicTime: in.time, fullTime: basicTime + 2, maxTime: fullTime + 3} )'

      changesFor("scores").should.eql [[{basicTime: 21, fullTime: 23, maxTime: 26}, {basicTime: 25, fullTime: 27, maxTime: 30}]]

    it 'filters elements of a sequence using a formula including a value from the input and named values', ->
      parseUserFunctions 'games = [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]'
      parseUserFunctions 'pointsFactor = 6; fudgeFactor = 4'
      parseUserFunctions 'highScores = select( games, in.score >= pointsFactor + fudgeFactor )'

      changes.should.eql [{games: [ { time: 21, score: 10 }, { time: 25, score: 7}, { time: 28, score: 11} ]},
                          {pointsFactor: 6}, {fudgeFactor: 4},
                          {highScores: [{ time: 21, score: 10 }, { time: 28, score: 11}]}]

  describe 'sequence and stream functions', ->

    it 'finds the total of the values in a stream using all_ function', ->
      providedAggregateFunctions
        total: (s) -> s.scan((acc, x) -> acc + x)
      parseUserFunctions 'tot = total(all_theInput)'

      inputs 20, 30, 40

      changesFor("tot").should.eql [null, 20, 50, 90]

    it 'finds the totals of the sequence values in a stream using plain version and their running total', ->
      providedAggregateFunctions
        total: (s) -> s.scan (acc, x) -> acc + x
      parseUserFunctions 'tot = total(theInput)'
      parseUserFunctions 'totAll = total(all_tot)'

      inputs [2, 3, 4], [5, 6], [7]

      changesFor("tot").should.eql [null, 9, 11, 7]
      changesFor("totAll").should.eql [null, 9, 20, 27]

    it 'finds the squares of all  the values in a stream using all_ function', ->
      providedSequenceFunctions
        square: (s) -> s.map((x) -> x * x)
      parseUserFunctions 'sq = square(all_theInput)'

      inputs 20, 30, 40

      changesFor("sq").should.eql [[], [400], [400, 900], [400, 900, 1600]]

    it 'finds the squares of the sequence values in a stream using plain version', ->
      providedSequenceFunctions
        square: (s) -> s.map((x) -> x * x)
      parseUserFunctions 'sq = square(theInput)'

      inputs [2, 3, 4], [5, 6], [7]

      changesFor("sq").should.eql [[], [4, 9, 16], [25, 36], [49]]

    it 'applies a transform function to an input stream using all_ version of function', ->
      parseUserFunctions 'sq = fromEach(all_theInput, in * in)'
      inputs 20, 30, 40
      changesFor("sq").should.eql [[], [400], [400, 900], [400, 900, 1600]]

    it 'applies a transform function to the sequence values in a stream using plain version', ->
      parseUserFunctions 'sq = fromEach(theInput, in * in)'
      inputs [2, 3, 4], [5, 6], [7]
      changesFor("sq").should.eql [[], [4, 9, 16], [25, 36], [49]]       # TODO should first be null or []?

    it.skip 'uses a stream return function', ->
      providedStreamReturnFunctions
        widgetFactor: (a) -> inputSubj.map (x) -> x + a
      parseUserFunctions 'wf = widgetFactor(3)'

      inputSubj.onNext 20
      inputSubj.onNext 30
      inputSubj.onNext 40

      changesFor("wf").should.eql [null, 23, 33, 43]


  describe 'updates dependent expressions and notifies changes', ->
    it 'to a constant value formula when it is set and changed', ->
      parseUserFunctions 'price = 22.5; tax_rate = 0.2'
      parseUserFunctions 'price = 33.5'
      changes.should.eql [{price:22.5}, {'tax_rate':0.2}, {price: 33.5}]

    it 'to a constant value formula when it is set and removed and set again', ->
      parseUserFunctions 'price = 20; tax_rate = 0.2; total = price + (price * tax_rate)'
      runner.removeUserFunction 'price'
      parseUserFunctions 'price = 30'
      changes.should.eql [{price:20}, {'tax_rate':0.2}, {total: 24}, {price: null}, {total: 0}, {total: 36}, {price: 30}]

    it 'to a function set after it is observed', ->
      observeNamedChanges 'price'

      parseUserFunctions 'price = 22.5'
      parseUserFunctions 'tax_rate = 0.2'
      parseUserFunctions 'price = 33.5'

      changes.should.eql [{price:null}, {price:22.5}, {tax_rate:0.2}, {price: 33.5}]
      namedChanges.should.eql [{price:null}, {price:22.5}, {price: 33.5}]

    it.skip 'to a function that uses an event stream via a provided function', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      inputSubj.onNext 'Aarhon'
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:'Zorgon'}]

    it.skip 'of a function that calls a function that uses an event stream via a provided function', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'number = theInput(); plusOne = number + 1'
      inputSubj.onNext 10
      inputSubj.onNext 20

      changes.should.eql [{number:null}, {plusOne:1}, {number:10}, {plusOne:11}, {number:20}, {plusOne:21}]


    it.skip 'to a function that uses an event stream via a provided function with arguments', ->
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

      changes.should.eql [{ materials: unknown('materials') }, {labour: unknown('labour')  }, {total: unknown('materials') }, {materials: 35 }, {total: unknown('labour') }, {labour: 25 }, {total: 60 }]

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

      changes.should.eql [{materials: 35}, {labour: unknown('labour')}, {total: unknown('labour')}, {labour:25}, {total: 60}]

    it 'on individual named value including initial value', ->

      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aaa = 10'

      observeNamedChanges 'aaa'
      observeNamedChanges 'xxx'
      observeNamedChanges 'bbb'

      parseUserFunctions 'bbb = theInput()'
      inputSubj.onNext 'value of bbb'

      namedChanges.should.eql [{aaa: 10}, {xxx: null}, {bbb: null}, {bbb: 'value of bbb'}]

  describe 'buffers value changes', ->

    it 'for each input', ->
      providedStreamFunctions
        unpackLists: (s) -> s.flatMap( (x) -> [].concat x)

      parseUserFunctions 'itemsIn = input'
      parseUserFunctions 'items = unpackLists(itemsIn)'
      parseUserFunctions 'doubled = items * 2'
      sendInputs 'itemsIn', [4, 5, 6], 7, [], [8, 9]

      bufferedChanges.should.eql [{itemsIn: [4, 5, 6]}, {items: 6}, {doubled: 12},
        {itemsIn: 7}, {items: 7}, {doubled: 14},
        {itemsIn: []},
        {itemsIn: [8, 9]}, {items: 9}, {doubled: 18}]


  describe 'removes named functions so that', ->

    it 'is no longer in the functions collection', ->
      parseUserFunctions 'a = 10; b = 20'
      removeUserFunction 'a'
      runner.userFunctions.should.not.have.property 'a'

    it 'all changes sends a null and no longer invokes callback', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      inputSubj.onNext 'Aarhon'

      removeUserFunction 'aliens'
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:null}]

    it 'named change sends a null and no longer invokes callback', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      observeNamedChanges 'aliens'
      inputSubj.onNext 'Aarhon'

      removeUserFunction 'aliens'
      inputSubj.onNext 'Zorgon'

      namedChanges.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:null}]

    it 'does nothing for a non-existent function', ->
      removeUserFunction 'xxx'

    it 'does nothing if a function removed twice', ->
      parseUserFunctions 'aliens = theInput()'
      removeUserFunction 'aliens'
      removeUserFunction 'aliens'

    it 'does nothing if a function removed twice while still in use by other functions', ->
      parseUserFunctions 'aliens = "zorg"; greetings =  "Hi " + aliens'
      removeUserFunction 'aliens'
      removeUserFunction 'aliens'

    it 'sends null to other functions that use it', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      parseUserFunctions 'greetings = "Hi " + aliens '
      observeNamedChanges 'greetings'
      inputSubj.onNext 'Aarhon'

      removeUserFunction 'aliens'
      inputSubj.onNext 'Zorgon'

      namedChanges.should.eql [{greetings: 'Hi null'}, {greetings:'Hi Aarhon'}, {greetings:'Hi null'}]
      changes.should.eql [{aliens:null}, {greetings: 'Hi null'}, {aliens:'Aarhon'}, {greetings:'Hi Aarhon'}, {aliens:null}, {greetings:'Hi null'}]

    it 'can add a function with the same name as one removed', ->
      parseUserFunctions 'a = 10; b = 20; c = a * b'
      removeUserFunction 'c'
      parseUserFunctions 'c = a + b'

      changes.should.eql [{a: 10}, {b: 20}, {c: 200}, {c: null}, {c: 30}]

    it 'can add a function with the same name after removing all functions', ->
      parseUserFunctions 'a = 10; b = 20; c = a * b'
      removeUserFunction 'a'
      removeUserFunction 'b'
      removeUserFunction 'c'
      parseUserFunctions 'a = 10; b = 20; c = a + b'

      changes.should.eql [{a: 10}, {b: 20}, {c: 200}, {a: null}, {c: 0}, {b: null}, {c: 0}, {c: null}, {a: 10}, {b: 20}, {c: 30}]

    it 'can add a function with the same name and forward reference after removing all functions', ->
      parseUserFunctions 'c = a * 2; a = 10'
      removeUserFunction 'c'
      removeUserFunction 'a'
      parseUserFunctions 'c = a + 2; a = 10'

      changes.should.eql [
        { "a": error('a', 'Unknown name')}
        { "c": error('a', 'Unknown name')}
        { "a": 10}
        { "c": 20}
        { "c": null}
        { "a": null}
        { "a": error('a', 'Unknown name')}
        { "c": error('a', 'Unknown name')}
        { "a": 10}
        { "c": 12}
      ]

    it 'destroy removes all user functions', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput(); humans = theInput()'
      inputSubj.onNext 'Aarhon'

      runner.destroy()
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {humans:null}, {aliens:'Aarhon'}, {humans:'Aarhon'}, {aliens:null}, {humans:null}]


    #      test of internals
    it 'cleans up user function subjects when no longer used', ->
      providedStreams { theInput: inputSubj }
      parseUserFunctions 'aliens = theInput()'
      parseUserFunctions 'greetings = "Hi " + aliens '
      runner.userFunctionSubjects.should.have.property('aliens')
      runner.userFunctionSubjects.should.have.property('greetings')

      removeUserFunction 'aliens'
      runner.userFunctionSubjects.should.have.property('aliens')
      runner.userFunctionSubjects.should.have.property('greetings')

      removeUserFunction 'greetings'
      runner.userFunctionSubjects.should.not.have.property('aliens')
      runner.userFunctionSubjects.should.not.have.property('greetings')
      runner.userFunctionImpls.should.not.have.property('aliens')
      runner.userFunctionImpls.should.not.have.property('greetings')

