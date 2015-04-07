_ = require 'lodash'
TextParser = require '../parser/TextParser'

module.exports = class TextRunner

  constructor: (@runner) ->
    @_defs = []

  clear: -> @removeFunction f.name for f in @functionDefinitions()

  load: (text) ->
    loadedDefs = new TextParser(text).functionDefinitionMap()

  asText: ->

  functionDefinitions: -> (f for f in @_defs)

  updateFunction: (name, definition) ->
    newDef = (name) ->
      d = {name}
      @_defs.push d
      d

    def = _.find @_defs, (x) -> x.name == name or newDef(name)
    @runner.addUserFunction name, parseFunction(definition).expr
    def.definition = definition

  removeFunction: (name) ->
    def = _.find @_defs, (x) -> x.name == name
    @runner.removeUserFunction name
    @_defs.pull def
