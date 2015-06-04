_ = require 'lodash'
TextParser = require '../parser/TextParser'

class FunctionError
  constructor: (@name, text, @error) ->
    @expr = {text}

module.exports = class TextLoader

  constructor: (@runner) ->
    @_defs = []
    @_values = {}
    @runner.onValueChange (name, value) => @_values[name] = value

  clear: ->
    @runner.removeUserFunction f.name for f in @_defs
    @_defs = []

  loadDefinitions: (text) ->
    @_defs = @_defs.concat @parseDefinitions text
    @setFunction f for f in @_defs

  asText: ->
    ("#{d.name} = #{d.expr.text.trim()};\n" for d in @_defs).join('')

  functionDefinitions: -> @_defs[..]


  functionDefinitionsAndValues: -> _.map @_defs, (def) => {name: def.name, definition: def, value: @_valueFor(def)}

  getFunction: (name) -> _.find @_defs, (x) -> x.name == name
  getFunctionAsText: (name) -> @getFunction(name).expr.text

  setFunctionAsText: (name, definition, oldName, beforeName) ->
    try
      funcDef = new TextParser(name + ' = ' + definition).functionDefinition()
      @setFunction funcDef, oldName, beforeName
    catch error
      funcError = new FunctionError name, definition.trim(), error
      @setFunctionError funcError, oldName, beforeName

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
    @_defs[defIndex] = funcDef
    @runner.addUserFunction funcDef

  setFunctionError: (funcError, oldName, beforeName) ->
    @removeFunction funcError.name
    defIndex = @_defIndex funcError.name
    if defIndex == -1
      beforeIndex = @_defIndex beforeName
      if beforeIndex == -1
        defIndex = @_defs.length
      else
        defIndex = beforeIndex
        # insert new element in middle of array
        @_defs[beforeIndex...beforeIndex] = null
    @_defs[defIndex] = funcError

  removeFunction: (name) ->
    def = _.find @_defs, (x) -> x.name == name
    @runner.removeUserFunction name
    _.pull @_defs, def

  _defIndex: (name) -> _.findIndex @_defs, (x) -> x.name == name

  _valueFor: (def) ->
    switch
      when def instanceof FunctionError
        def.error
      else
        @_values[def.name] or null

  parseDefinitions: (text) ->  new TextParser(text).functionDefinitionList()
