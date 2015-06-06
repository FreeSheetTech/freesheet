should = require 'should'

Operations = require './Operations'

describe 'Operations', ->
  operations = new Operations('AFunction')

  describe 'Date subtraction', ->

    it 'return null if one argument is null', ->
      should.equal operations.subtract(new Date(), null), null
      should.equal operations.subtract(null, new Date()), null

    it 'return zero if both arguments are null', ->
      should.equal operations.subtract(null, null), 0

  describe 'Aggregates', ->

    it 'can be merged with add', ->
      a = {a:10, b: 20}
      b = {p: "ppp", q: "qqq"}
      operations.add(a, b).should.eql {a:10, b: 20, p: "ppp", q: "qqq"}

    it 'can be merged with add and second object properties override the first', ->
      a = {a:10, b: 20}
      b = {p: "ppp", q: "qqq", a:30}
      operations.add(a, b).should.eql {a:30, b: 20, p: "ppp", q: "qqq"}
