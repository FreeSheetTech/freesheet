Rx = require 'rx'
Period = require './Period'

ReactiveRunner = require '../runtime/ReactiveRunner'
value = (fn) -> fn.kind = ReactiveRunner.VALUE; fn

module.exports = {
  now: Rx.Observable.interval(1000).startWith(1).map(-> new Date())
  seconds: value (n) -> Period.seconds n
  asSeconds: value (period) -> period.asSeconds()
  dateValue: value (text) -> new Date(text)
}