# Top level facade for Freesheet

Sheet = require './Sheet'

sheets = []
findSheet = (name) -> (s for s in sheets when s.name == name)[0]

module.exports = {
  sheets: (name = null) -> if name then findSheet(name) else sheets[..]

  createSheet: (name) ->
    sheet = new Sheet(name)
    sheets.push sheet
    sheet
}
