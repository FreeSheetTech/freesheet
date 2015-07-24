# Top level facade for Freesheet

Rx = require 'rx'
Sheet = require './Sheet'
RunnerEnvironment = require '../runtime/RunnerEnvironment'
CoreFunctions = require '../functions/CoreFunctions'
TimeFunctions = require '../functions/TimeFunctions'
JsCodeGenerator = require '../code/JsCodeGenerator'

module.exports = class Freesheet

  constructor: ->
    @_sheets = []
    @_environment = new RunnerEnvironment()

  sheets: (name) ->
    if name
      (s for s in @_sheets when s.name == name)[0]
    else @_sheets[..]

  createSheet: (name) ->
    sheet = new Sheet(name, @_environment)
    sheet.addFunctions CoreFunctions
    sheet.addFunctions TimeFunctions
    @_sheets.push sheet
    sheet

  destroy: -> @_environment.destroy()

  trace: (onOff) -> JsCodeGenerator.trace onOff