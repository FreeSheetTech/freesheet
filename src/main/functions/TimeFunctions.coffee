Rx = require 'rx'
Period = require './Period'
ReactiveRunner = require '../runtime/ReactiveRunner'

pageLoadTime = new Date()

streamReturn = (fn) -> fn.returnKind = ReactiveRunner.STREAM_RETURN; fn

module.exports = {
  now: streamReturn (interval = 1000) -> Rx.Observable.interval(interval).startWith(new Date()).map(-> new Date())
  seconds: (n) -> Period.seconds n
  asSeconds: (period) -> period?.asSeconds() or null
  dateValue: (text) -> new Date(text)
  pageLoadTime: -> pageLoadTime
}