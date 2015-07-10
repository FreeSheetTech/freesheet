Rx = require 'rx'
_ = require 'lodash'
ReactiveRunner = require '../runtime/ReactiveRunner'

#transform = (fn) -> fn.kind = 'transform'; fn
transformStream = (fn) -> fn.kind = ReactiveRunner.TRANSFORM_STREAM; fn
aggregate = (fn) -> fn.returnKind = ReactiveRunner.AGGREGATE_RETURN; fn
sequence = (fn) -> fn.returnKind = ReactiveRunner.SEQUENCE_RETURN; fn
streamReturn = (fn) -> fn.returnKind = ReactiveRunner.STREAM_RETURN; fn
apply = (funcOrValue, x) -> if typeof funcOrValue == 'function' then funcOrValue(x) else funcOrValue

module.exports = {
  fromEach: transformStream (s, func) -> s.map (x) -> apply(func, x)
  select: transformStream (s, func) -> s.filter (x) -> apply(func, x)

  shuffle: (seq) -> _.shuffle seq

  count: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + 1
  sum: aggregate (seq) -> seq.scan 0, (acc, x) -> acc + x
  first: aggregate (seq) -> seq.first()
  sort: aggregate (seq) -> seq.scan [], (acc, x) -> _.sortBy acc.concat(x)
  sortBy: aggregate transformStream (seq, func) -> seq.scan [], (acc, x) -> _.sortBy acc.concat(x), func

  ifElse: (test, trueValue, falseValue) -> if test then trueValue else falseValue
  and: (a, b) -> a and b
  or: (a, b) -> a or b
}