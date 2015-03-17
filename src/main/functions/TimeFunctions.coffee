Rx = require 'rx'
ReactiveRunner = require '../runtime/ReactiveRunner'
value = (fn) -> fn.kind = ReactiveRunner.VALUE; fn
stream = (fn) -> fn.kind = ReactiveRunner.STREAM; fn

module.exports = {
  now: stream -> Rx.Observable.interval(1000).startWith(1).map(-> new Date())
}