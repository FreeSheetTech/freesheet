_ = require 'lodash'
TextParser = require '../parser/TextParser'
{FunctionError} = require '../error/Errors'

module.exports = class TextLoader

  argList = (funcDef) -> if funcDef.argDefs?.length then "(#{(a.name for a in funcDef.argDefs).join ', '})" else ""

  constructor: (@runner) ->
    @_defs = []
    @_values = {}
    @runner.onValueChange (name, value) => @_values[name] = value

  clear: ->
    @runner.destroy()
    @_defs = []

  loadDefinitions: (text) ->
    @_setFunctionOrError f for f in @parseDefinitions text

  asText: ->
    ("#{d.name}#{argList d} = #{d.expr.text.trim()};\n" for d in @_defs).join('')

  functionDefinitions: -> @_defs[..]
  functionDefinitionsAndValues: -> _.map @_defs, (def) => {name: def.name, definition: def, value: @_valueFor(def)}

  getFunction: (name) -> _.find @_defs, (x) -> x.name == name
  getFunctionAsText: (name) -> @getFunction(name).expr.text

  setFunctionAsText: (nameAndArgs, definition, replaceName, beforeName) ->
    funcDef = new TextParser(nameAndArgs + ' = ' + definition).functionDefinition()
    @_setFunctionOrError funcDef, replaceName, beforeName
    funcDef

  setFunction: (funcDef, replaceName, beforeName) ->
    if replaceName and replaceName != funcDef.name then @removeFunction replaceName
    @_addDefinition funcDef, beforeName
    @runner.addUserFunction funcDef

  setFunctionError: (funcError, beforeName) ->
    @removeFunction funcError.name
    @_addDefinition funcError, beforeName

  removeFunction: (name) ->
    def = _.find @_defs, (x) -> x.name == name
    @runner.removeUserFunction name
    _.pull @_defs, def

  _setFunctionOrError: (funcDef, replaceName, beforeName) ->
    if funcDef instanceof FunctionError
      @setFunctionError funcDef, beforeName
    else
      @setFunction funcDef, replaceName, beforeName

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
