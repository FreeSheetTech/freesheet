should = require 'should'

Operations = require './Operations'

describe 'Date subtraction operations', ->
  it 'return null if one argument is null', ->
    should.equal Operations.subtract(new Date(), null), null
    should.equal Operations.subtract(null, new Date()), null

  it 'return zero if both arguments are null', ->
    should.equal Operations.subtract(null, null), 0

