should = require 'should'
Rx = require 'rx'
_ = require 'lodash'

Eval = require './ReactiveEvaluators'

describe 'ReactiveEvaluators', ->

  describe 'ExpressionFunction', ->

    it 'creates callable unchanging function from its Evaluator', ->
      inArg = new Eval.ArgRef('in')
      multBy2 = new Eval.Multiply(null, inArg, new Eval.Literal(null, 2))
      exprFunc = new Eval.ExpressionFunction multBy2

      functionsReceived = []
      evalCompletesReceived = []
      exprFunc.observable().subscribe (f) ->
        if _.isFunction(f)
          functionsReceived.push f
        else
          evalCompletesReceived.push f

      exprFunc.activate({userFunctions: {}, providedFunctions: {}, argSubjects: {}})

      latestFunction = -> _.last functionsReceived
      latestFunction()(5).should.eql 10
      latestFunction()(20).should.eql 40
      evalCompletesReceived.length.should.eql 1

    it 'updates callable function for changes with other input values', ->
      inArg = new Eval.ArgRef('in')
      a = new Eval.FunctionCallNoArgs null, 'a'
      aSubject = new Rx.ReplaySubject(2)
      multByA = new Eval.Multiply(null, inArg, a)
      exprFunc = new Eval.ExpressionFunction multByA

      functionsReceived = []
      evalCompletesReceived = []
      exprFunc.observable().subscribe (f) ->
        if _.isFunction(f)
          functionsReceived.push f
        else
          evalCompletesReceived.push f

      exprFunc.activate({userFunctions: { a: aSubject}, providedFunctions: {}, argSubjects: {}})
      latestFunction = -> _.last functionsReceived

      aSubject.onNext 2
      aSubject.onNext Eval.EvaluationComplete
      latestFunction()(5).should.eql 10

      aSubject.onNext 3
      aSubject.onNext Eval.EvaluationComplete
      latestFunction()(5).should.eql 15

    it 'callable function can use same input value twice', ->
      inArg = new Eval.ArgRef('in')
      sq = new Eval.Multiply(null, inArg, inArg)
      exprFunc = new Eval.ExpressionFunction sq

      functionsReceived = []
      evalCompletesReceived = []
      exprFunc.observable().subscribe (f) ->
        if _.isFunction(f)
          functionsReceived.push f
        else
          evalCompletesReceived.push f

      exprFunc.activate({userFunctions: {}, providedFunctions: {}, argSubjects: {}})
      latestFunction = -> _.last functionsReceived

      latestFunction()(5).should.eql 25
      latestFunction()(7).should.eql 49

