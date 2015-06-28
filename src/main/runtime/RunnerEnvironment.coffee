Rx = require 'rx'
ReactiveRunner = require './ReactiveRunner'

module.exports = class RunnerEnvironment

  constructor: ->
    @runners = {}

  add: (name, runner) ->
    @runners[name] = runner
    runner.addProvidedStreamReturnFunction('fromSheet', @_fromSheetFn)

  _fromSheetFn: (sheetName, functionName) =>
    runner = @runners[sheetName]
    stream = new Rx.BehaviorSubject()
    callback = (_, value) -> stream.onNext value
    runner.onValueChange(callback, functionName)
    stream
