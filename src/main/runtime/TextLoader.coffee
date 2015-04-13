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

  setFunctionAsText: (name, definition, oldName, beforeName) ->
    funcDef = new TextParser(name + ' = ' + definition).functionDefinition()
    @setFunction funcDef, oldName, beforeName

  setFunction: (funcDef, oldName, beforeName) ->
    if oldName and oldName != funcDef.name then @removeFunction oldName
    defIndex = @_defIndex funcDef.name
    if defIndex == -1
      beforeIndex = @_defIndex beforeName
      if beforeIndex == -1
        defIndex = @_defs.length
      else
        defIndex = beforeIndex
        # insert new element in middle of array
        @_defs[beforeIndex...beforeIndex] = null
    @runner.addUserFunction funcDef
    @_defs[defIndex] = funcDef

  removeFunction: (name) ->
    def = _.find @_defs, (x) -> x.name == name
    @runner.removeUserFunction name
    _.pull @_defs, def

  _defIndex: (name) -> _.findIndex @_defs, (x) -> x.name == name

  parseDefinitions: (text) ->  new TextParser(text).functionDefinitionList()
