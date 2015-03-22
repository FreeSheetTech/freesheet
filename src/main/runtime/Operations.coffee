Period = require '../functions/Period'

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
    when a instanceof Period and b instanceof Period
      new Period(a.millis - b.millis)
    when a instanceof Date and b instanceof Date
      new Period(a.getTime() - b.getTime())
    when a instanceof Date and b instanceof Period
      new Date(a.getTime() - b.millis)
    else
      a - b

module.exports = {add, subtract}