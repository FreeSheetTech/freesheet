Rx = require 'rx'
_ = require 'lodash'
ReactiveRunner = require '../runtime/ReactiveRunner'

#transform = (fn) -> fn.kind = 'transform'; fn
transformStream = (fn) -> fn.kind = ReactiveRunner.TRANSFORM_STREAM; fn
aggregate = (fn) -> fn.returnKind = ReactiveRunner.AGGREGATE_RETURN; fn
sequence = (fn) -> fn.returnKind = ReactiveRunner.SEQUENCE_RETURN; fn
streamReturn = (fn) -> fn.returnKind = ReactiveRunner.STREAM_RETURN; fn
stream = (fn) -> fn.kind = ReactiveRunner.STREAM; fn
apply = (funcOrValue, x) -> if typeof funcOrValue == 'function' then funcOrValue(x) else funcOrValue


isNumber = (text) -> text and text.match(/^\d*\.?\d+$|^\d+.?\d*$/)
fromText = (text) -> if isNumber(text) then parseFloat(text) else text
lines = (text) -> if text? then text.split '\n' else []

module.exports = {
  lines
  nonEmptyLines: (text) -> (l.trim() for l in lines(text) when l.trim())
  fromCsvLine: (text) -> (fromText(l.trim()) for l in text.split(','))

  item: (index, list) -> list[index - 1]
  fromEach: transformStream (s, func) -> s.map (x) -> apply(func, x)
  select: transformStream (s, func) -> s.filter (x) -> apply(func, x)
  differentValues: sequence (s) -> s.distinct()

  merge: stream (s1, s2) -> Rx.Observable.merge s1, s2
  onChange: stream (s1, s2) -> s1.filter((x) -> !!x).combineLatest(s2, (a, b) -> [a, b]).distinctUntilChanged((pair) -> pair[0]).map((pair) -> pair[1])

  shuffle: (seq) -> _.shuffle seq

  count: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + 1
  sum: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + x
  first: aggregate (seq) -> seq.first()
  collect: aggregate (seq) -> seq.scan [], (acc, x) -> if x? then acc.concat(x) else acc
  sort: aggregate (seq) -> seq.scan [], (acc, x) -> _.sortBy acc.concat(x)
  sortBy: aggregate transformStream (seq, func) -> seq.scan [], (acc, x) -> _.sortBy acc.concat(x), func

  unpackLists: stream (s) -> s.flatMap( (x) -> [].concat x)

  ifElse: (test, trueValue, falseValue) -> if test then trueValue else falseValue
  and: (a, b) -> a and b
  or: (a, b) -> a or b
}