Parser = require './Parser'
_ = require 'lodash'

module.exports = class TextParser
  constructor: (@text) ->

  expression: -> Parser.parse @text, {startRule: 'expression'}
  functionDefinition: -> Parser.parse @text, {startRule: 'functionDefinition'}
  functionDefinitionList: ->  Parser.parse @text, {startRule: 'functionDefinitionList'}
  functionDefinitionMap: -> _.indexBy @functionDefinitionList(), 'name'
