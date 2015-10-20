{Range} = require 'atom'
{spawn} = require 'child_process'
CommandView = require './command-view'

history = []

module.exports =
  activate: ->
    atom.commands.add 'atom-workspace', "pipe:run", => @run()

  run: ->
    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView(editor)
    return if not editor?

    new CommandView history, (commandString) ->
      if not commandString
        view.focus()
        return

      history.push commandString
      if history.length > 300
        history.shift()

      if atom.project.getPaths().length
        commandString = "cd '#{atom.project.getPaths()[0]}' && #{commandString}"
      properties = { reversed: true, invalidate: 'never' }

      ranges = editor.getSelectedBufferRanges()
      wg = new WaitGroup ->
        editor.groupChangesSinceCheckpoint()
        view.focus()

      wg.add(ranges.length)

      editor.createCheckpoint()
      for range, i in ranges
        marker = editor.markBufferRange range, properties
        processRange marker, editor, commandString, wg

processRange = (marker, editor, commandString, wg) ->
  stdout = ''
  stderr = ''

  proc = spawn process.env.SHELL, ["-l", "-c", commandString]

  proc.stdout.on 'data', (text) ->
    stdout += text

  proc.stderr.on 'data', (text) ->
    stderr += text

  proc.on 'close', (code) ->
    text = stderr || stdout
    editor.setTextInBufferRange(marker.getBufferRange(), text)
    wg.done()

  proc.stdin.write(editor.getTextInBufferRange(marker.getBufferRange()))
  proc.stdin.end()

class WaitGroup
  constructor: (cb) ->
    @n = 0
    @cb = cb

  add: (n) ->
    @n += n

  done: ->
    @n -= 1
    if @n <= 0
      @cb()
