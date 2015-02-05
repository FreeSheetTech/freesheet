Parser = require './Parser'

class TextParser
  constructor: (@text) ->

  ast: ->
    Parser.parse @text


module.exports = {TextParser}