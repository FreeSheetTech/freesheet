Rx = require 'rx'
Period = require './Period'

pageLoadTime = new Date()

module.exports = {
  now: Rx.Observable.interval(1000).startWith(1).map(-> new Date())
  seconds: (n) -> Period.seconds n
  asSeconds: (period) -> period?.asSeconds() or null
  dateValue: (text) -> new Date(text)
  pageLoadTime: -> pageLoadTime
}