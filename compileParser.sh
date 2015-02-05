#!/bin/bash

pegjs -e "module.exports" src/main/parser/Parser.pegjs src/main/parser/Parser.js
cp src/main/parser/Parser.js target/coffeejs/parser/Parser.js
