#!/usr/bin/env bash

coffee --map -o target/coffeejs/ast -c src/main/ast/*.coffee
coffee --map -o target/coffeejs/code -c src/main/code/*.coffee
coffee --map -o target/coffeejs/freesheet -c src/main/freesheet/*.coffee
coffee --map -o target/coffeejs/functions -c src/main/functions/*.coffee
coffee --map -o target/coffeejs/parser -c src/main/parser/*.coffee
coffee --map -o target/coffeejs/runtime -c src/main/runtime/*.coffee
coffee --map -o target/coffeejs/tool -c src/main/tool/*.coffee

coffee --map -o target/coffeejs/ast -c src/test/ast/*.coffee
coffee --map -o target/coffeejs/code -c src/test/code/*.coffee
coffee --map -o target/coffeejs/freesheet -c src/test/freesheet/*.coffee
coffee --map -o target/coffeejs/functions -c src/test/functions/*.coffee
coffee --map -o target/coffeejs/parser -c src/test/parser/*.coffee
coffee --map -o target/coffeejs/runtime -c src/test/runtime/*.coffee
coffee --map -o target/coffeejs/tool -c src/test/rx/*.coffee
