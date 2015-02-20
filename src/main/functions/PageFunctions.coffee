input = (inputName) ->
  isNumeric = (s) -> s and s.match(/^\d*\.?\d+$|^\d+.?\d*$/)
  convertValue = (s)  -> if isNumeric(s) then parseFloat(s) else s

  inputEl = $("input[name='#{inputName.value}']")  #TODO switch input stream if input name changes
  Rx.Observable.fromEvent(inputEl, 'change').map((e) -> e.target.value).startWith(inputEl.val()).map(convertValue)

module.exports = {input}