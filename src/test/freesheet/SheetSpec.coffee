should = require 'should'
Sheet = require './Sheet'

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

    it 'for error', ->
      sheet.update 'fn1', '10('
      functionChanges.should.eql [['error', 'fn1', '10(', 'Error in formula on line 1 at position 3' ]]
