# Top level facade for Freesheet

Rx = require 'rx'
Sheet = require './Sheet'
RunnerEnvironment = require '../runtime/RunnerEnvironment'
CoreFunctions = require '../functions/CoreFunctions'
TimeFunctions = require '../functions/TimeFunctions'

sheets = []
environment = new RunnerEnvironment()

findSheet = (name) -> (s for s in sheets when s.name == name)[0]

module.exports = {
  sheets: (name = null) -> if name then findSheet(name) else sheets[..]

  createSheet: (name) ->
    sheet = new Sheet(name, environment)
    sheet.addFunctions CoreFunctions
    sheet.addFunctions TimeFunctions
    sheets.push sheet
    sheet
}
