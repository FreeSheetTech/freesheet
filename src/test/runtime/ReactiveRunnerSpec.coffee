should = require 'should'
Rx = require 'rx'
TextParser = require '../parser/TextParser'
ReactiveRunner = require './ReactiveRunner'


describe 'ReactiveRunner runs', ->

  @timeout 5000

  runner = null
  changes = null
  namedChanges = null
  inputSubj = null


  providedFunctions = (functionMap) -> runner.addProvidedFunctions functionMap
  providedStreamFunctions = (functionMap) -> runner.addProvidedStreamFunctions functionMap
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

  describe 'runs expressions', ->
    it 'all arithmetic operations', ->
      parseUserFunctions 'a=100'
      parseUserFunctions '  p=a+2  '
      parseUserFunctions 'q = 150   -  a  '
      parseUserFunctions 'r =1200 / a'
      parseUserFunctions 's= a * 5.2'

      changes.should.eql [{a: 100}, {p: 102}, {q: 50}, {r :12}, {s: 520}]

    it 'all comparison operations on numbers', ->
      parseUserFunctions 'a = 100 > 100'
      parseUserFunctions 'b = 100 < 101'
      parseUserFunctions 'c = 101 >= 100'
      parseUserFunctions 'd = 101 <= 100'
      parseUserFunctions 'e = 101 == 100'
      parseUserFunctions 'f = 101 <> 100'
      changes.should.eql [{a: false}, {b: true}, {c: true}, {d: false}, {e: false}, {f:true}]

    it 'concatenates strings', ->
      parseUserFunctions 'a = "The A"'
      parseUserFunctions 'aa = a + 10 + " times"'

      changes.should.eql [{a: 'The A'}, {aa: 'The A10 times'}]

    it 'creates objects for aggregation expressions using constants, function calls and operations', ->
      parseUserFunctions 'x = 20; obj = {a: 10, b: "Fred", c: x, d: x + 30}'
      changes.should.eql [{x: 20}, {obj: {a: 10, b: "Fred", c: 20, d: 50}}]

    it 'function with no args returning constant', ->
      parseUserFunctions ''' theAs = "aaaAAA" '''
      changes.should.eql [{theAs: "aaaAAA"}]

    it 'function with no args returning constant calculated addition expression', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3 '''
      changes.should.eql [{twelvePlusThree: 15}]

    it 'function with no args returning another function with no args', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3; five = twelvePlusThree / 3 '''
      changesFor('five').should.eql [5]

    it 'function using a provided stream function with no args', ->
      providedStreamFunctions { theInput: -> new Rx.BehaviorSubject(20) }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]

    it 'function using a provided stream function with some args', ->
      providedStreamFunctions { theInput: -> new Rx.BehaviorSubject(20) }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]

    it 'function using a user function with name overriding a built-in function', ->
      providedStreamFunctions { theInput: -> new Rx.BehaviorSubject(20) }
      parseUserFunctions '''theInput = 30'''
      parseUserFunctions '''inputMinusTwo = theInput - 2 '''
      changesFor('inputMinusTwo').should.eql [28]

    it 'function using a provided value function with no args', ->
      providedFunctions { theInput: -> 20 }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]


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
      providedFunctions
        addOne: (a) -> a + 1
        getTheAnswer: (a, b, c) -> a + b - c

      parseUserFunctions 'q = getTheAnswer(100, b + addOne(a), getTheAnswer ( 4, 10, c)  )'

      changes.should.eql [{a: 10}, {b: 20}, {c: 5}, {q: 122}]



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
      providedStreamFunctions { theInput: -> inputSubj }
      parseUserFunctions 'aliens = theInput()'
      inputSubj.onNext 'Aarhon'
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:'Zorgon'}]

    it 'of a function that calls a function that uses an event stream via a provided function', ->
      providedStreamFunctions { theInput: -> inputSubj }
      parseUserFunctions 'number = theInput(); plusOne = number + 1'
      inputSubj.onNext 10
      inputSubj.onNext 20

      changes.should.eql [{number:null}, {plusOne:1}, {number:10}, {plusOne:11}, {number:20}, {plusOne:21}]


    it 'to a function that uses an event stream via a provided function with arguments', ->
      providedStreamFunctions inputValueWithSuffix: (prefixStream, suffixStream) ->
        inputSubj.combineLatest prefixStream, suffixStream, (v, p, s) -> p + v + s

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
      providedStreamFunctions { theInput: -> inputSubj }
      parseUserFunctions 'materials = 35'
      parseUserFunctions 'labour = theInput()'
      parseUserFunctions 'total = materials + labour'

      inputSubj.onNext 25
      parseUserFunctions 'materials = 50'

      changes.should.eql [{materials: 35}, {labour:null}, {total: 35}, {labour:25}, {total: 60}, {materials: 50}, {total: 75}]


    it 'adds two changing values in function set in between', ->
      providedStreamFunctions { theInput: -> inputSubj }
      parseUserFunctions 'materials = 35'
      parseUserFunctions 'total = materials + labour'
      parseUserFunctions 'labour = theInput()'

      inputSubj.onNext 25

      changes.should.eql [{materials: 35}, {labour:null}, {total: 35}, {labour:25}, {total: 60}]

    it 'on individual named value including initial value', ->

      providedStreamFunctions { theInput: -> inputSubj }
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
