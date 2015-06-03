# Facade for a TextLoader and an associated ReactiveRunner

ReactiveRunner = require '../runtime/ReactiveRunner'
TextLoader = require '../runtime/TextLoader'

module.exports = class Sheet

  constructor: (@name) ->
    @runner = new ReactiveRunner()
    @loader = new TextLoader(@runner)

  clear: -> @loader.clear()
  load: (text) -> @loader.loadDefinitions text
  text: -> @loader.asText()
  update: (name, definition, oldName, beforeName) -> @loader.setFunctionAsText name, definition, oldName, beforeName
  remove: (name) -> @loader.removeFunction name
  formula: (name) -> @loader.getFunction name
  formulaText: (name) -> @loader.getFunctionAsText name
  formulas: -> @loader.functionDefinitions()
  formulasAndValues: -> @loader.functionDefinitionsAndValues()
  addFunctions: (functionMap) -> @runner.addProvidedFunctions functionMap
  onValueChange: (callback) -> @runner.onValueChange callback
  onFormulaChange: (callback) -> @runner.onFunctionChange callback
