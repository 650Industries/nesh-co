exports.__doc__ = """
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

"""

co = require 'co'
escodegen = require 'escodegen'
esprima = require 'esprima-fb'
optimist = require 'optimist'
vm = require 'vm'

pkg = require './package'

# Even though we don't use it in this file, we require instapromise
# here for its side effects, since it will modify the global Object
# prototype and let you do things like `yield fs.promise.readFile`, etc.
instapromise = require 'instapromise'

# Note: this doesn't work right now.
# See https://github.com/danielgtaylor/nesh/issues/9
optimist.describe ['y', 'co'], "Use co so you can yield async values, etc."

if optimist.argv.co? or optimist.argv.y?

  exports.setup = (context) ->
    { nesh } = context
    process.versions.nesh_co = pkg.version
    try
      process.versions.co = require(require.resolve('co').replace('index.js', 'package.json')).version
    catch
      process.versions.co = '?'

    nesh.defaults.prompt = nesh.defaults.prompt.replace '> ', '*> '

    # Put a custom `util.log` formatter on Promises if one doesn't already exist
    unless Promise::inspect?
      _promiseObjectSequenceId = 0
      Promise::inspect = (depth) ->
        """A custom `util.format` for Promises"""

        # See: https://iojs.org/api/util.html#util_custom_inspect_function_on_objects
        unless @___inspect_promiseObjectSequenceId___?
          @___inspect_promiseObjectSequenceId___ = _promiseObjectSequenceId++

        "[Promise ##{ @___inspect_promiseObjectSequenceId___ }]"


  exports.postStart = (context) ->
    { repl } = context

    originalEval = repl.eval

    repl.eval = (input, context, filename, callback) ->

      #context.___nesh_co_co_wrap___ = co.wrap

      useCo = false

      # We only need to bother thinking about using co if the string
      # 'yield' appears in the input
      if input.indexOf('yield') != -1

        try
          # First, try to parse the input as-is; if it parses, then
          # we can just eval as usual
          esprima.parse input
          useCo = false

        catch
          # ... but that doesn't work, try wrapping the code in a function*
          # and seeing if that will parse

          try
            wrapped = "(function* () { #{ input.trim() }; })"
            ast = esprima.parse wrapped
            body = ast.body[0].expression.body.body
            last = body[body.length - 1]

            # If we end with an ExpressionStatement and not
            # a ReturnStatement, we'll convert it
            if last.type is 'ExpressionStatement'
              body[body.length - 1] =
                type: 'ReturnStatement'
                argument: last.expression

              wrapped = escodegen.generate ast

            #context.___nesh_co_wrapped___ = wrapped
            useCo = true
          catch
            # If that didn't work, there's some problem with it, and we
            # should just parse it straight up I think
            useCo = false

      if useCo
        if repl.useGlobal
          result = vm.runInThisContext wrapped
        else
          result = vm.runInContext wrapped, context

        co.wrap(result)().then (result) ->

          # There may be something important about calling the original
          # eval, so we do that here
          tmpName = "$___nesh_co_result#{ Math.random().toString().substring(2) }___$"
          context[tmpName] = result
          originalEval tmpName, context, filename, (err, result) ->
            # Delete the temporarily stored value so it can be garbage collected
            delete context[tmpName]
            callback err, result

        , (err) ->
          callback err

      else
        originalEval input, context, filename, callback
