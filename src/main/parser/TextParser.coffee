Parser = require './Parser'
{FunctionError} = require '../ast/FunctionDefinition'
_ = require 'lodash'

module.exports = class TextParser
  constructor: (@text) ->

  expression: -> Parser.parse @text, {startRule: 'expression'}
  functionDefinition: ->
    try
      Parser.parse @text, {startRule: 'functionDefinition'}
    catch error
      [name, def] = @text.trim().split(new RegExp(' *= *'))
      new FunctionError name, def.trim(), error

  functionDefinitionList: ->
    funcDefs = (f for f in @text.split /;/ when f.trim())
    (new TextParser(f).functionDefinition() for f in funcDefs)
  functionDefinitionMap: -> _.indexBy @functionDefinitionList(), 'name'
