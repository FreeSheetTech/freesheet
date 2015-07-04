Rx = require 'rx'
ReactiveRunner = require './ReactiveRunner'
{CalculationError} = require '../error/Errors'

module.exports = class RunnerEnvironment

  constructor: ->
    @runners = {}

  add: (name, runner) ->
    @runners[name] = runner
    runner.addProvidedStreamReturnFunction('fromSheet', @_fromSheetFn)

  destroy: -> r.destroy() for k, r of @runners

  _fromSheetFn: (sheetName, functionName) =>
    runner = @runners[sheetName]
    if not runner then return new Rx.BehaviorSubject(new CalculationError(null, "Sheet #{sheetName} could not be found"))
    if not runner.hasUserFunction(functionName) then return new Rx.BehaviorSubject(new CalculationError(null, "Name #{functionName} could not be found in sheet #{sheetName}"))
    stream = new Rx.BehaviorSubject()
    callback = (_, value) -> stream.onNext value
    runner.onValueChange callback, functionName
    stream
