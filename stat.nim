import play
import game
import sequtils
import times
import os

players = newDefaultPlayers()
for player in players.mitems:
  player.kind = Computer
players = newPlayers()
startNewGame()
for player in players:
  echo $player.color
  echo $player.kind

blueDeck.resetDeck
for card in blueDeck.drawPile.mapIt it.title:
  echo card

# for i in 0..1:
let time = cpuTime()
startNewGame()
configState = StatGame
while not gameWon:
  # if phaseIs == EndTurn:
  #   echo "turnPlayer.color: ",$turnPlayer.color
  #   echo "turnPlayer.cash: ",turnPlayer.cash
# while configState != GameWon:
  echo phaseIs
  aiTakeTurnPhase()
  # if phase == EndTurn:
  #   sleep 1000  

echo cpuTime()-time