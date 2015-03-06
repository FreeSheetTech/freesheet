Rx = require 'rx'

module.exports = {
  fromEach: (seq, func) -> (func(x) for x in seq)
}