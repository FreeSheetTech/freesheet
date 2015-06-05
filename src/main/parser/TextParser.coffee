Parser = require './Parser'
{FunctionError} = require '../ast/FunctionDefinition'
_ = require 'lodash'

module.exports = class TextParser
  constructor: (@text) ->

  expression: -> Parser.parse @text, {startRule: 'expression'}
  functionDefinition: ->
    defText = @text.trim()
    try
      Parser.parse defText, {startRule: 'functionDefinition'}
    catch error
      [name, def] = defText.split(new RegExp(' *= *'))
      namePartLength = defText.length - defText.replace(new RegExp('\\w+ *= *'), '').length
      error.columnInExpr = error.column - namePartLength
      new FunctionError name, def.trim(), error

  functionDefinitionList: ->
    funcDefs = (f for f in @text.split /;/ when f.trim())
    (new TextParser(f).functionDefinition() for f in funcDefs)
  functionDefinitionMap: -> _.indexBy @functionDefinitionList(), 'name'
