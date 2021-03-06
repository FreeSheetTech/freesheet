should = require 'should'
Sheet = require './Sheet'
Freesheet = require './Freesheet'

describe 'Sheet', ->

  sheet = null
  changes = null
  namedChanges = null
  functionChanges = null

  callback = (name, value) -> received = {}; received[name] = value; changes.push received

  beforeEach ->
    sheet = new Sheet('sheet1')
    changes = []
    functionChanges = []
    namedChanges = []
    sheet.onValueChange callback
    sheet.onFormulaChange (type, name, text, error) ->
      change = [type, name]
      change.push text if text
      change.push error if error
      functionChanges.push change


  describe 'notifies function changes', ->
    it 'for successful add', ->
      sheet.update 'fn1', '10'
      functionChanges.should.eql [['addOrUpdate', 'fn1', '10']]

    it 'for successful remove', ->
      sheet.update 'fn1', '10'
      sheet.remove 'fn1'
      functionChanges.should.eql [['addOrUpdate', 'fn1', '10'], ['remove', 'fn1']]

    it 'for clear', ->
      sheet.update 'fn1', '10'
      sheet.update 'fn2', '20'
      sheet.clear()
      functionChanges.should.eql [['addOrUpdate', 'fn1', '10'], ['addOrUpdate', 'fn2', '20'], ['remove', 'fn1'], ['remove', 'fn2']]

    it 'for error', ->
      sheet.update 'fn1', '10('
      functionChanges.should.eql [['error', 'fn1', '10(', 'Error in formula on line 1 at position 3' ]]

  describe 'notifies value changes', ->
    it 'to one named value', ->
      outputReceived = null
      sheet.update 'inputA', 'input'
      sheet.update 'inputB', 'input'
      sheet.update 'outputA', 'inputA + 10'
      sheet.onValueChange 'outputA', (name, v) -> outputReceived = v
      sheet.input 'inputA', 20
      sheet.input 'inputB', 50
      outputReceived.should.eql 30

    it 'to any named value', ->
      outputReceived = null
      sheet.update 'inputA', 'input'
      sheet.update 'outputA', 'inputA + 10'
      sheet.onValueChange (name, v) -> outputReceived = v
      sheet.input 'inputA', 20
      outputReceived.should.eql 30

  describe 'Freesheet facade', ->
    it 'creates sheets and connects them to environment', ->
      freesheet = new Freesheet()
      s1 = freesheet.createSheet('sheet1')
      s2 = freesheet.createSheet('sheet2')
      freesheet.sheets('sheet1').update 'fn1', '10'
      freesheet.sheets('sheet2').update 'fn1FromS1', 'fromSheet("sheet1", "fn1")'
      s2.formulasAndValues()[0].value.should.eql 10
      freesheet.destroy()

