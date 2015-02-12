should = require 'should'
Rx = require 'rx'
{TextParser} = require '../parser/TextParser'
{ReactiveRunner} = require './ReactiveRunner'


describe 'ReactiveRunner runs', ->

  runner = null
  changes = null
  namedChanges = null

  providedFunctions = (functionMap) -> runner.addProvidedFunctions functionMap
  parse = (text) -> new TextParser(text).functionDefinitionMap()
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

  describe 'runs expressions', ->
    it 'function with no args returning constant', ->
      parseUserFunctions ''' theAs = "aaaAAA" '''
      changes.should.eql [{theAs: "aaaAAA"}]

    it 'function with no args returning constant calculated addition expression', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3 '''
      changes.should.eql [{twelvePlusThree: 15}]

    it 'function with no args returning another function with no args', ->
      parseUserFunctions '''twelvePlusThree = 12 + 3; five = twelvePlusThree / 3 '''
      changesFor('five').should.eql [5]

    it 'function using a built-in function', ->
      providedFunctions { theInput: -> new Rx.BehaviorSubject(20) }
      parseUserFunctions '''inputMinusTwo = theInput() - 2 '''
      changesFor('inputMinusTwo').should.eql [18]

  describe 'notifies changes', ->
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
      inputSubj = new Rx.Subject()
      providedFunctions { theInput: -> inputSubj }
      parseUserFunctions 'aliens = theInput()'
      inputSubj.onNext 'Aarhon'
      inputSubj.onNext 'Zorgon'

      changes.should.eql [{aliens:null}, {aliens:'Aarhon'}, {aliens:'Zorgon'}]

    it 'to a function that uses an event stream via a provided function with arguments', ->
      inputSubj = new Rx.Subject()
      providedFunctions inputValueWithSuffix: (suffixStream) ->
        inputSubj.combineLatest suffixStream, (v, s) -> v + s

      parseUserFunctions 'aliens = inputValueWithSuffix("stuff")'
      inputSubj.onNext 'Aarhon'
      observeNamedChanges 'aliens'

      inputSubj.onNext 'Zorgon'

      namedChanges.should.eql [{aliens: 'Aarhonstuff'}, {aliens: 'Zorgonstuff'}]


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
