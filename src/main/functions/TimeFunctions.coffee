Rx = require 'rx'
Period = require './Period'

module.exports = {
  now: Rx.Observable.interval(1000).startWith(1).map(-> new Date())
  seconds: (n) -> Period.seconds n
  asSeconds: (period) -> period.asSeconds()
  dateValue: (text) -> new Date(text)
}