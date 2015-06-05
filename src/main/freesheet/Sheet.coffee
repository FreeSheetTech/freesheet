# Facade for a TextLoader and an associated ReactiveRunner

Rx = require 'rx'
ReactiveRunner = require '../runtime/ReactiveRunner'
TextLoader = require '../runtime/TextLoader'
{FunctionDefinition, FunctionError} = require '../ast/FunctionDefinition'

module.exports = class Sheet

  constructor: (@name) ->
    @runner = new ReactiveRunner()
    @loader = new TextLoader(@runner)
    @functionChanges = new Rx.Subject()


  clear: -> @loader.clear()
  load: (text) -> @loader.loadDefinitions text
  text: -> @loader.asText()
  update: (name, definition, oldName, beforeName) ->
    funcDef = @loader.setFunctionAsText name, definition, oldName, beforeName
    notification = switch
      when funcDef instanceof FunctionDefinition then ['addOrUpdate', name]
      when funcDef instanceof FunctionError then ['error', name]
      else throw new Error 'Unknown function definition type: ' + funcDef
    @functionChanges.onNext notification

  remove: (name) ->
    @loader.removeFunction name
    @functionChanges.onNext ['remove', name]

  formula: (name) -> @loader.getFunction name
  formulaText: (name) -> @loader.getFunctionAsText name
  formulas: -> @loader.functionDefinitions()
  formulasAndValues: -> @loader.functionDefinitionsAndValues()
  addFunctions: (functionMap) -> @runner.addProvidedFunctions functionMap
  onValueChange: (callback) -> @runner.onValueChange callback
  onFormulaChange: (callback) -> @functionChanges.subscribe (typeName) -> callback typeName[0], typeName[1]

