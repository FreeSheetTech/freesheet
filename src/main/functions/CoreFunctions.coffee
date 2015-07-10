Rx = require 'rx'
_ = require 'lodash'
ReactiveRunner = require '../runtime/ReactiveRunner'

transform = (fn) -> fn.kind = 'transform'; fn
aggregate = (fn) -> fn.returnKind = ReactiveRunner.AGGREGATE_RETURN; fn
sequence = (fn) -> fn.returnKind = ReactiveRunner.SEQUENCE_RETURN; fn
streamReturn = (fn) -> fn.returnKind = ReactiveRunner.STREAM_RETURN; fn

module.exports = {
  fromEach: transform (seq, func) -> (func(x) for x in seq)
  select: transform (seq, func) -> (x for x in seq when func(x))
  shuffle: (seq) -> _.shuffle seq

  count: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + 1
  sum: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + x
  first: aggregate (seq) -> seq.first()
  sort: aggregate (seq) -> seq.scan [], (acc, x) -> _.sortBy acc.concat(x)

  ifElse: (test, trueValue, falseValue) -> if test then trueValue else falseValue
  and: (a, b) -> a and b
  or: (a, b) -> a or b
}