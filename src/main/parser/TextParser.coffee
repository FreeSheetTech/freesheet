Parser = require './Parser'

class TextParser
  constructor: (@text) ->

  expression: -> Parser.parse @text, {startRule: 'expression'}
  functionDefinition: -> Parser.parse @text, {startRule: 'functionDefinition'}


module.exports = {TextParser}