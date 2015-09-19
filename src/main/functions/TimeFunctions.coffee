Rx = require 'rx'
Period = require './Period'
FunctionTypes = require '../runtime/FunctionTypes'
{EvaluationComplete} = require '../code/ReactiveEvaluators'

notEvaluationComplete = (x) -> x isnt EvaluationComplete

pageLoadTime = new Date()

streamReturn = (fn) -> fn.kind = FunctionTypes.STREAM_RETURN; fn

module.exports = {
  seconds: (n) -> Period.seconds n
  asSeconds: (period) -> period?.asSeconds() or null
  dateValue: (text) -> new Date(text)
  pageLoadTime: -> pageLoadTime

  #TODO better implementation
  now: streamReturn (intervalObs = new Rx.Observable.from(1000)) ->
    stream = new Rx.BehaviorSubject()
    intervalObs.filter( notEvaluationComplete ).subscribe (interval) =>
      timeTicks = Rx.Observable.interval(interval).startWith(new Date()).map(-> new Date())
      timeTicks.subscribe (x) ->
        stream.onNext x
        stream.onNext EvaluationComplete

    stream

}