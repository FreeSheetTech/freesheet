Rx = require 'rx'
ReactiveRunner = require '../runtime/ReactiveRunner'
_ = require 'lodash'

transform = (fn) -> fn.kind = ReactiveRunner.TRANSFORM; fn
value = (fn) -> fn.kind = ReactiveRunner.VALUE; fn

module.exports = {
  fromEach: transform (seq, func) -> (func(x) for x in seq)
  select: transform (seq, func) -> (x for x in seq when func(x))
  shuffle: value (seq) -> _.shuffle seq
  count: value (seq) -> seq.length
}