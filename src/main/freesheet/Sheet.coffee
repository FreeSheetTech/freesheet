# Facade for a TextLoader and an associated ReactiveFunctionRunner

Rx = require 'rx'
ReactiveFunctionRunner = require '../runtime/ReactiveFunctionRunner'
TextLoader = require '../runtime/TextLoader'
{FunctionDefinition} = require '../ast/FunctionDefinition'
{FunctionError} = require '../error/Errors'

module.exports = class Sheet

  errorText = (error) -> "Error in formula on line #{error.line} at position #{error.columnInExpr}"

  constructor: (@name, @environment) ->
    @runner = new ReactiveFunctionRunner()
    @environment?.add @name, @runner
    @loader = new TextLoader(@runner)
    @functionChanges = new Rx.Subject()


  clear: ->
    defs = @loader.functionDefinitions()
    @loader.clear()
    @functionChanges.onNext ['remove', d.name] for  d in defs

  load: (text) -> @loader.loadDefinitions text
  text: -> @loader.asText()
  update: (nameAndArgs, definition, replaceName, beforeName) ->
    funcDef = @loader.setFunctionAsText nameAndArgs, definition, replaceName, beforeName
    notification = switch
      when funcDef instanceof FunctionDefinition then ['addOrUpdate', funcDef.name, funcDef.expr.text]
      when funcDef instanceof FunctionError then ['error', funcDef.name, funcDef.expr.text, errorText(funcDef.error)]
      else throw new Error 'Unknown function definition type: ' + funcDef
    @functionChanges.onNext notification

  remove: (name) ->
    @loader.removeFunction name
    @functionChanges.onNext ['remove', name]

  formula: (name) -> @loader.getFunction name
  formulaText: (name) -> @loader.getFunctionAsText name
  formulas: -> @loader.functionDefinitions()
  formulasAndValues: -> @loader.functionDefinitionsAndValues()
  inputs: -> @runner.getInputs()
  input: (name, value) -> @runner.sendInput name, value
  addFunctions: (functionMap) -> @runner.addProvidedFunctions functionMap
  onValueChange: (callback) -> @runner.onValueChange callback
  onEveryValueChange: (callback) -> @runner.onValueChange callback
  onFormulaChange: (callback) -> @functionChanges.subscribe (updateArgs) -> callback.apply(null, updateArgs)

