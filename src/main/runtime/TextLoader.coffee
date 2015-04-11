_ = require 'lodash'
TextParser = require '../parser/TextParser'

module.exports = class TextLoader

  constructor: (@runner) ->
    @_defs = []

  clear: ->
    @runner.removeUserFunction f.name for f in @_defs
    @_defs = []

  loadDefinitions: (text) ->
    @_defs = @parseDefinitions text
    @setFunction f for f in @_defs

  asText: ->
    ("#{d.name} = #{d.expr.text.trim()};\n" for d in @_defs).join('')

  functionDefinitions: -> @_defs[..]

  setFunctionAsText: (name, definition, oldName) ->
    funcDef = new TextParser(name + ' = ' + definition).functionDefinition()
    @setFunction funcDef, oldName

  setFunction: (funcDef, oldName) ->
    if oldName then @removeFunction oldName
    defIndex = _.findIndex @_defs, (x) -> x.name == funcDef.name
    if defIndex == -1 then defIndex = @_defs.length
    @runner.addUserFunction funcDef
    @_defs[defIndex] = funcDef

  removeFunction: (name) ->
    def = _.find @_defs, (x) -> x.name == name
    @runner.removeUserFunction name
    _.pull @_defs, def

  parseDefinitions: (text) ->  new TextParser(text).functionDefinitionList()
