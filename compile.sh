#!/usr/bin/env bash

echo Compiling coffeescript

for d in $(ls src/main)
do
 echo "Compiling main/$d"
 coffee --map -o target/coffeejs/$d -c src/main/$d/*.coffee
done

for d in $(ls src/test)
do
 echo "Compiling test/$d"
 coffee --map -o target/coffeejs/$d -c src/test/$d/*.coffee
done

