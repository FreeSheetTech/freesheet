ReactiveRunner = require('../runtime/ReactiveRunner')
TextParser = require('../parser/TextParser')
pageFunctions = require('../functions/PageFunctions')


module.exports = class TableWorksheet

  constructor: (@el, changeCallback) ->
    @runner = new ReactiveRunner()
    @runner.onChange changeCallback
    @runner.addProvidedStreams pageFunctions
    @_parseTable(@runner)

  _parseTable: (runner) ->
    parseFormula = (name, formula) -> new TextParser("#{name} = #{formula}").functionDefinition()
    setFormula = (name, formula) -> runner.addUserFunction parseFormula(name, formula)

    sheetRows = @el.find('tr')
    sheetRows.each ->
      rowEl = $(this)
      cells = rowEl.find('td')
      name  = cells.eq(0).text().trim()
      formulaEl = cells.eq(1).find('input')
      setFormula name, formulaEl.val().trim()
      valueCell = cells.eq(2)
      runner.onChange ((name, value) -> valueCell.text value), name

      rowEl.on 'change', -> setFormula name, formulaEl.val().trim()


