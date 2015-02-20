#!/bin/bash

mkdir -p dist

browserify -o dist/franji.js \
  -r ./target/coffeejs/parser/TextParser.js:text-parser \
  -r ./target/coffeejs/runtime/ReactiveRunner.js:reactive-runner \
  -r ./target/coffeejs/functions/PageFunctions.js:page-functions \
  -r ./target/coffeejs/worksheet/TableWorksheet.js:table-worksheet
