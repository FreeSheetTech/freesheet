Rx = require 'rx'
_ = require 'lodash'
FunctionTypes = require '../runtime/FunctionTypes'
{EvaluationComplete} = require '../code/ReactiveEvaluators'

transform = (fn) -> fn.kind = FunctionTypes.TRANSFORM; fn
streamReturn = (fn) -> fn.kind = FunctionTypes.STREAM_RETURN; fn
apply = (funcOrValue, x) -> if typeof funcOrValue == 'function' then funcOrValue(x) else funcOrValue

isNumber = (text) -> text and text.match(/^\d*\.?\d+$|^\d+.?\d*$/)
fromText = (text) -> if isNumber(text) then parseFloat(text) else text
lines = (text) -> if text? then text.split '\n' else []

module.exports = {
  lines
  nonEmptyLines: (text) -> (l.trim() for l in lines(text) when l.trim())
  fromCsvLine: (text) ->
    if not text?.trim()
      []
    else
      (fromText(l.trim()) for l in text.split(','))

  item: (index, list) -> list[index - 1]
  fromEach: transform (s, func) -> s.map (x) -> apply(func, x)
  select: transform (s, func) -> s.filter (x) -> apply(func, x)
  differentValues: (s) -> _.uniq s

  merge: streamReturn (s1, s2) -> Rx.Observable.merge s1, s2

  onChange: streamReturn (s1, s2) ->
    subj = new Rx.Subject()
    pendingS2 = null
    latestS2 = null
    s2.subscribe (x) ->
      if x is EvaluationComplete
        latestS2 = pendingS2
      else
        pendingS2 = x

    s1.filter( (x) -> x is EvaluationComplete ).subscribe (x) ->
      subj.onNext latestS2
      subj.onNext EvaluationComplete

    subj


  shuffle: (seq) -> _.shuffle seq

  count: (s) -> s.length
  sum: (s) -> _.sum s
  first: (s) -> _.first s
  sort: (s) -> _.sortBy s
  sortBy: transform (s, func) -> _.sortBy s, func

  all:   streamReturn (s) ->
    items = []
    subj = new Rx.Subject(items)
    s.subscribe (x) ->
      if x is EvaluationComplete
        subj.onNext items
        subj.onNext EvaluationComplete
      else
        items = items.concat x
    subj

  unpackLists: streamReturn (s) ->
    subj = new Rx.Subject()
    s.subscribe (x) ->
      if _.isArray(x)
        subj.onNext y for y in x
      else
        subj.onNext x
    subj

  ifElse: (test, trueValue, falseValue) -> if test then trueValue else falseValue
  and: (a, b) -> a and b
  or: (a, b) -> a or b
}