#!/usr/bin/env bash

echo Running mocha tests
node node_modules/mocha/bin/_mocha --recursive --ui bdd --reporter spec target/coffeejs