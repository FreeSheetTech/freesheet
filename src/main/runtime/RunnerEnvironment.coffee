Rx = require 'rx'
{CalculationError} = require '../error/Errors'
{EvaluationComplete} = require '../code/ReactiveEvaluators'


notEvaluationComplete = (x) -> x isnt EvaluationComplete
sendError = (stream, message) ->
  stream.onNext new CalculationError(null, message)
  stream.onNext EvaluationComplete


module.exports = class RunnerEnvironment

  constructor: ->
    @runners = {}

  add: (name, runner) ->
    @runners[name] = runner
    runner.addProvidedStreamReturnFunction('fromSheet', @_fromSheetFn)

  destroy: -> r.destroy() for k, r of @runners

  #TODO better implementation
  _fromSheetFn: (sheetNameObs, functionNameObs) =>
    stream = new Rx.ReplaySubject(2)
    sheetName = null
    functionName = null
    names = sheetNameObs.filter( notEvaluationComplete ).combineLatest functionNameObs.filter( notEvaluationComplete ), (sheetName, functionName) -> [sheetName, functionName]
    names.subscribe (pair) =>
      [sheetName, functionName] = pair
      runner = @runners[sheetName]
      switch
        when not runner then sendError stream, "Sheet #{sheetName} could not be found"
        when not runner.hasUserFunction(functionName) then sendError stream, "Name #{functionName} could not be found in sheet #{sheetName}"
        else
          callback = (name, value) ->
            stream.onNext value
            stream.onNext EvaluationComplete
          runner.onValueChange callback, functionName

    stream
