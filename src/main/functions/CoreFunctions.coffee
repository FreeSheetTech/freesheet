Rx = require 'rx'

module.exports = {
  fromEach: (seq, func) -> (func(x) for x in seq)
  select: (seq, func) -> (x for x in seq when func(x))
}