should = require 'should'

Operations = require './Operations'

describe 'Date subtraction operations', ->
  operations = new Operations('AFunction')

  it 'return null if one argument is null', ->
    should.equal operations.subtract(new Date(), null), null
    should.equal operations.subtract(null, new Date()), null

  it 'return zero if both arguments are null', ->
    should.equal operations.subtract(null, null), 0

