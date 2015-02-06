#nesh-co
A plugin for nesh that lets you yield async values in the REPL

If you do normal REPL things, everything should work the same as before.
But if you type `yield` into the REPL, then this plugin will cause that
line to be evaluated wrapped by co, so you can get the value back
synchronously.

We use esprima to parse the input to tell the difference between regular
inputs that don't need to be transformed and those that do, and we will
also rewrite the `yield` cases that we wrap in a function to include a
return at the end if you end with an ExpressionStatement so that you
don't have to type `return yield` all the time to get values back!

This plugin also does a few other things for your convenience.
- It changes the prompt to have a * in it so you know its enabled
- It includes instapromise so you can do work easily with traditional
  Node-style async functions that use callbacks
- It puts a custom `util.log` inspect function in place on Promises
  so that they show up as something more useful than '{}'

