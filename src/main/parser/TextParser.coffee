Parser = require './Parser'

class TextParser
  constructor: (@text) ->

  expression: -> Parser.parse @text, {startRule: 'expression'}
  functionDefinition: -> Parser.parse @text, {startRule: 'functionDefinition'}
  functionDefinitionMap: ->
    functions = Parser.parse @text, {startRule: 'functionDefinitionList'}
#    console.log "Functions ", functions
    result = {}
    result[f.name] = f for f in functions
    result


module.exports = {TextParser}