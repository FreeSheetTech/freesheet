# Top level facade for Freesheet

Rx = require 'rx'
Sheet = require './Sheet'
CoreFunctions = require '../functions/CoreFunctions'
TimeFunctions = require '../functions/TimeFunctions'

sheets = []
findSheet = (name) -> (s for s in sheets when s.name == name)[0]

module.exports = {
  rx: Rx     #TODO expose this in dist file
  sheets: (name = null) -> if name then findSheet(name) else sheets[..]

  createSheet: (name) ->
    sheet = new Sheet(name)
    sheet.addFunctions CoreFunctions
    sheet.addFunctions TimeFunctions
    sheets.push sheet
    sheet
}
