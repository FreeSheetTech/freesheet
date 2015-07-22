Rx = require 'rx'
_ = require 'lodash'
Period = require '../functions/Period'
{CalculationError} = require '../error/Errors'

module.exports = class Operations

  constructor: (@name, @getInput) ->

  checkArgs = (args) ->
    for a in args
      if a instanceof Error
        throw a

  checkResult = (value) ->
    switch
      when value == Number.POSITIVE_INFINITY or value == Number.NEGATIVE_INFINITY then throw new Error 'Divide by zero'
      when _.isNaN value then throw new Error 'Invalid values in calculation'
      else value

  _error: (err) -> if err instanceof CalculationError then err else new CalculationError(@name, err.message)

  _errorCheck: (fn) -> =>
    try
      checkArgs arguments
      checkResult fn.apply this, arguments
    catch e
      @_error e

  _valueCheck: (value) ->
    try
      checkResult value
    catch e
      @_error e

  add: (a, b) ->
    switch
      when a instanceof Period and b instanceof Period
        new Period(a.millis + b.millis)
      when a instanceof Date and b instanceof Period
        new Date(a.getTime() + b.millis)
      when _.isPlainObject(a) and _.isPlainObject(b)
        _.merge {}, a, b
      when _.isArray(a) and _.isArray(b)
        a.concat b
      else
        a + b

  subtract: (a, b) ->
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


  combine: (streams..., combineFunction) -> Rx.Observable.combineLatest streams, @_errorCheck(combineFunction)
  subject: (value) -> new Rx.BehaviorSubject @_valueCheck value
  eval: (fn) -> if fn?.call then fn else -> fn
  input: (name) -> @getInput name
  trace: (text, expr) -> console.log(text); expr
