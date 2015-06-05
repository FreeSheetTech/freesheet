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
    sheet.onFormulaChange (type, name) -> functionChanges.push [type, name]


  describe 'notifies function changes', ->
    it 'for successful add', ->
      sheet.update 'fn1', '10'
      functionChanges.should.eql [['addOrUpdate', 'fn1']]

   it 'for successful remove', ->
      sheet.update 'fn1', '10'
      sheet.remove 'fn1'
      functionChanges.should.eql [['addOrUpdate', 'fn1'], ['remove', 'fn1']]

    it 'for error', ->
      sheet.update 'fn1', '10('
      functionChanges.should.eql [['error', 'fn1']]
