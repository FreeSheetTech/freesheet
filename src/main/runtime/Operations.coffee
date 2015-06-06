Rx = require 'rx'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'

add = (a, b) ->
  switch
    when a instanceof Period and b instanceof Period
      new Period(a.millis + b.millis)
    when a instanceof Date and b instanceof Period
      new Date(a.getTime() + b.millis)
    else
      a + b

subtract = (a, b) ->
  switch
    when a instanceof Date and b == null or a == null and b instanceof Date
      null
    when a instanceof Period and b instanceof Period
      new Period(a.millis - b.millis)
    when a instanceof Date and b instanceof Date
      new Period(a.getTime() - b.getTime())
    when a instanceof Date and b instanceof Period
      new Date(a.getTime() - b.millis)
    else
      a - b

combine = (streams..., combineFunction) -> Rx.Observable.combineLatest streams, combineFunction
subject = (value) -> new Rx.BehaviorSubject value
checkArgs = (args) ->
  for a in args
    if a instanceof Error
      throw a

error = (err) ->
  if err instanceof CalculationError then err else new CalculationError("theFunction", err.message)

module.exports = {add, subtract, combine, subject, checkArgs, error}