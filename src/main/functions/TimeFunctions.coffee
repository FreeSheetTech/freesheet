ReactiveRunner = require '../runtime/ReactiveRunner'
value = (fn) -> fn.kind = ReactiveRunner.VALUE; fn

module.exports = {
  timeNow: value -> new Date()
}