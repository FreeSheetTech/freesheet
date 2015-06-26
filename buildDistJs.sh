#!/bin/bash

DIST_FILE=dist/freesheet.js
echo Building distribution file $DIST_FILE

mkdir -p $(dirname $DIST_FILE)

node_modules/.bin/browserify -o $DIST_FILE \
  -r rx \
  -r lodash \
  -r ./target/coffeejs/parser/TextParser.js:text-parser \
  -r ./target/coffeejs/runtime/ReactiveRunner.js:reactive-runner \
  -r ./target/coffeejs/runtime/TextLoader.js:text-loader \
  -r ./target/coffeejs/functions/CoreFunctions.js:core-functions \
  -r ./target/coffeejs/functions/TimeFunctions.js:time-functions \
  -r ./target/coffeejs/freesheet/Freesheet.js:freesheet \
  -r ./target/coffeejs/freesheet/Sheet.js:freesheet-sheet \
  -r ./target/coffeejs/error/Errors.js:freesheet-errors
