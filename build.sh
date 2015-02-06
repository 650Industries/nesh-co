#!/usr/bin/env sh
coffee -c $* *.coffee

echo '#nesh-co' > README.md
coffee -e 'intdoc=require("intdoc");console.log(intdoc(require(".")).doc);' >> README.md
