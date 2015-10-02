should = require 'should'
_ = require 'lodash'
Freesheet = require '../freesheet/Freesheet'
fs = require 'fs'

describe 'League Table calculation', ->

  @timeout 30000

  class SheetOutputs
    constructor: (@sheet, @outputNames...) ->
      @values = {}
      for n in @outputNames
        callback = (name, value) => @values[name] = value
        @sheet.onValueChange callback, n

      @all = {}
      @sheet.onValueChange (name, value) => @all[name] = value

  freesheet = null
  sheet = null
  outputs = null

  addResult = (homeTeam, homeGoals, awayTeam, awayGoals) ->   sheet.input 'singleResult', {homeTeam: homeTeam, homeGoals: homeGoals, awayTeam: awayTeam, awayGoals: awayGoals}
  isNumber = (text) -> text and text.match(/^\d*\.?\d+$|^\d+.?\d*$/)
  fromText = (text) -> if isNumber(text) then parseFloat(text) else text
  fromCsvLine = (text) -> (fromText(l.trim()) for l in text.split(','))


  beforeEach ->
    freesheet = new Freesheet()
    sheet = freesheet.createSheet('league')
    outputs = new SheetOutputs sheet, ['leagueTable']
    sheet.load code


  it 'has sorted team positions after three inputs', ->
    addResult 'Leeds', 2, 'Hull', 3
    addResult 'Hull',  3, 'Liverpool', 0
    addResult 'Leeds', 4, 'Liverpool', 1

#    console.log 'all', outputs.all
    outputs.values.leagueTable.should.eql [
      {team: 'Hull', points: 6}
      {team: 'Leeds', points: 3}
      {team: 'Liverpool', points: 0}
    ]

  it 'has sorted team positions after full season separate inputs', ->
    csvText = fs.readFileSync 'src/test/acceptance/premierleague-2013-14.csv', 'utf8'
    results = (fromCsvLine(l) for l in csvText.split '\n' when l.trim().length > 0)
#    console.log results
    for r in results
      [ht, hg, at, ag] = r
      addResult ht, hg, at, ag

    table = outputs.values.leagueTable
    console.log table
    table.length.should.eql 20
    table[0].should.eql { team: 'Man City', points: 86 }
    table[19].should.eql { team: 'Cardiff', points: 30 }


  code = '''
      resultPoints(t, result) = {team: t, points: pointsFromMatch(team, result) };
      pointsFromMatch(team, result) = ifElse(winner(team, result), 3, ifElse(draw(result), 1, 0));
      winner(team, result) = team == result.homeTeam and result.homeGoals > result.awayGoals
          or team == result.awayTeam and result.awayGoals > result.homeGoals;
      draw(result) = result.homeGoals == result.awayGoals;
      teamResults(team) = select(allResults, isInvolved(in, team));
      isInvolved(result, team) = team == result.homeTeam or team == result.awayTeam;
      totalPoints(t) = sum(fromEach(teamResults(t), resultPoints(t, in).points));
      teamPoints(t) = {team: t, points: totalPoints(t)};

      singleResult = input;
      allResults = all(singleResult);
      awayTeams = fromEach(allResults, in.awayTeam);
      homeTeams = fromEach(allResults, in.homeTeam);
      teams = differentValues(homeTeams + awayTeams);
      competitionResults = fromEach(teams, teamPoints(in));
      leagueTable = sortBy(competitionResults, 0-in.points);
'''