Rx = require 'rx'
should = require 'should'


describe 'Subjects and shares', ->

  it 'Subject can be resubscribed to different Subjects', ->
    source22 = new Rx.BehaviorSubject 22
    source33 = new Rx.BehaviorSubject 33
    subject = new Rx.BehaviorSubject null

    valuesReceived = []
    callback = (value) -> valuesReceived.push value

    subject.subscribe callback
    valuesReceived.should.eql [null]

    disp = source22.subscribe subject
    valuesReceived.should.eql [null, 22]

    disp.dispose()
    disp2 = source33.subscribe subject
    valuesReceived.should.eql [null, 22, 33]

  it 'Subject can have multiple subscribers', ->
    source22 = new Rx.BehaviorSubject 22
    source33 = new Rx.BehaviorSubject 33
    subject = new Rx.BehaviorSubject null

    valuesReceived1 = []
    callback1 = (value) -> valuesReceived1.push value

    valuesReceived2 = []
    callback2 = (value) -> valuesReceived2.push value

    subject.subscribe callback1
    valuesReceived1.should.eql [null]

    disp = source22.subscribe subject
    valuesReceived1.should.eql [null, 22]

    subject.subscribe callback2

    disp.dispose()
    disp2 = source33.subscribe subject
    valuesReceived1.should.eql [null, 22, 33]
    valuesReceived2.should.eql [22, 33]

