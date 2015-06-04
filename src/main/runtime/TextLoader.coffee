_ = require 'lodash'
TextParser = require '../parser/TextParser'
{FunctionError} = require '../ast/FunctionDefinition'

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
    funcDef = new TextParser(name + ' = ' + definition).functionDefinition()
    if funcDef instanceof FunctionError
      @setFunctionError funcDef, oldName, beforeName
    else
      @setFunction funcDef, oldName, beforeName

  setFunction: (funcDef, oldName, beforeName) ->
    if oldName and oldName != funcDef.name then @removeFunction oldName
    @_addDefinition funcDef, beforeName
    @runner.addUserFunction funcDef

  setFunctionError: (funcDef, oldName, beforeName) ->
    @removeFunction funcDef.name
    @_addDefinition funcDef, beforeName

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

  _addDefinition: (funcDef, beforeName) ->
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

  parseDefinitions: (text) ->  new TextParser(text).functionDefinitionList()
