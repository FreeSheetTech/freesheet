Rx = require 'rx'
_ = require 'lodash'

transform = (fn) -> fn.kind = 'transform'; fn

module.exports = {
  fromEach: transform (seq, func) -> (func(x) for x in seq)
  select: transform (seq, func) -> (x for x in seq when func(x))
  shuffle: (seq) -> _.shuffle seq
  count: (seq) -> seq.length
  sum: (seq) -> _.reduce seq, (total, n) -> total + n
  ifElse: (test, trueValue, falseValue) -> if test then trueValue else falseValue
  and: (a, b) -> a and b
  or: (a, b) -> a or b
}