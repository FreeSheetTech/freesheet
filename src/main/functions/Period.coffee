module.exports = class Period

  @seconds = (seconds) -> new Period(seconds * 1000)

  constructor: (@millis) ->

  asSeconds: -> @millis / 1000

