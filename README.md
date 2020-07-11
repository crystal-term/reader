<div align="center">
  <img src="./assets/term-logo.png" alt="term logo">
</div>

# Term::Reader

![spec status](https://github.com/crystal-term/reader/workflows/specs/badge.svg)

> A pure Crystal library that provides a set of methods for processing keyboard input in character, line and multiline modes. It maintains history of entered input with an ability to recall and re-edit those inputs. It lets you register to listen for keystroke events and trigger custom key events yourself.

**Term::Reader** provides an independant reader component for the crystal-term toolkit.

<div align="center">
  <img src="./assets/example.gif" alt="usage example">
</div>

## Compatibility

`Term::Reader` is not compatible with GNU Readline and doesn't aim to be. It is based completely on [tty-reader](https://github.com/piotrmurach/tty-reader) and shares a very similar API, but that could change as things progress.

## Features

- Pure Crystal
- Reading single keypresses
- Line editing
- Reading multiline input
- Ability to listen for keystroke events
- Track input history
- No global state
- Cross platform*

_\* Windows support is not yet implemented since Crystal itself doesn't support Windows natively._

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     term-reader:
       github: crystal-term/reader
   ```

2. Run `shards install`

## Usage

In just a few lines you can create a simple REPL.

```crystal
require "term-reader"
```

Initialize the reader:

```crystal
reader = Term::Reader.new
```

Then register to listen for key events, in this case for `Ctrl-x`. _(Escape doesn't work right currently.)_

```crystal
reader.on_key(:ctrl_x) do
  puts "Exiting..."
  exit(0)
end
```

Finally show the user a prompt, and keep looping until we exit:

```crystal
loop do
  reader.read_line("=> ")
end
```

## API

### read_keypress

To read a single stroke from the user, use `read_keypress`:

```crystal
reader.read_keypress
reader.read_keypress(nonblock: true)
```

### read_line

By default `read_line` works in `raw mode`, which means it behaves like a line editor that allows you to read each character and respond to `control characters` such as `Ctrl-a` and `Ctrl-b`, or navigate through history.

For example, to read a single line terminated by a newline character:

```crystal
reader.read_line
```

If you wish for keystrokes to be interpreted by the terminal instead, use `cooked` mode by setting `raw` to `false`:

```crystal
reader.read_line(raw: false)
```

Any non-interpreted characters received are written back to the terminal, however you can stop this by setting `echo` to `false`:

```crystal
reader.read_line(echo: false)
```

You can also provide a line prefix (prompt) by passing it as the first argument:

```crystal
reader.read_line("=> ")
# =>
```

To pre-populate the line content for editing, use the `value` option:

```crystal
reader.read_line("=>", value: "edit me")
# => edit me
```

### read_multiline

By default `read_multiline` works in `raw mode` which means it behaves like a multiline editor that allows you to edit each character, respond to `control characters` such as `Ctrl-a` and `Ctrl-b` or navigate through history.

For example, to read more than one line terminated by `Ctrl+d` or `Ctrl+z` use `read_multiline`:

```crystal
reader.read_multiline
# => [ "line1", "line2", ... ]
```

If you wish for the keystrokes to be interpreted by the terminal instead, use so called cooked mode by setting the `raw` option to `false`:

```crystal
reader.read_line(raw: false)
```

You can also provide a line prefix (prompt) displayed before input by passing a string as a first argument:

```crystal
reader.read_multiline("=> ")
```

### on_key

You can register to listen to keypress events. This can be done by calling `on_key` with the name of a key or keys:

```crystal
reader.on_key(:ctrl_x) { |key, event| ... }
```

Alternately, if you provide no keys all keypress events will be listened to:

```crystal
reader.on_key { |key, event| ... }
```

Two things are yielded to the block whenever a `on_key` event is fired. The name of the key that was pressed, as a string, and a `KeyEvent` object which includes the fields:

- `key` - the key that was pressed
- `value` - the value of the key pressed
- `line` - the content of the line currently being edited

The `value` returns the actual key pressed rather than its name.

The `key` is an object with the following fields:

- `name` - the name of the key
- `meta` - true if is non-standard key associated
- `shift` - true if shift key was pressed with this key
- `ctrl` - true if ctrl was pressed with this key

For example, to listen to vim navigation keys:

```crystal
reader.on_key do |key, event|
  case event.value
  when "j"
    # ...
  when "k"
    # ...
  end
end
```

Listeners are chainable, so you can subscribe to more than one event at once:

```crystal
prompt.on_key          { |key, event| ... }
      .on_key(:ctrl_x) { |key, event| ... }
```

## Configuration

### interrupt

By default the `InputInterrupt` exception will be rased when the user hits the interrupt key (`ctrl-c`). However, you can customize this behavior by passing the `interrupt` option. The available options are:

- `:error` - raises `IntputInterrupt` exception
- `:signal` - sends interrupt signal
- `:exit` - exits with a non-zero status code
- `:noop` - skips the handler
- `Proc` - a custom handler (not available yet)

For example, to send an interrupt signal do:

```crystal
reader = Term::Reader.new(interrupt: :signal)
```

### track_history

`read_line` and `read_multiline` provide a history buffer that tracks all lines entered during `Reader` interactions. The history buffer provides previous or next lines when the user presses the up and down arrows respectively. However, you can disable this feature by setting `track_history` to false.

```crystal
reader = Term::Reader.new(track_history: false)
```

### history_cycle

This option determines whether the history buffer allows for infinite navigation. By default it is set to false. You can change this:

```crystal
reader = Term::Reader.new(history_cycle: true)
```

### history_duplicates

This option controls whether duplicate lines are stored in history. By default set to true. You can change this:

```crystal
reader = term::reader.new(history_duplicates: false)
```

### history_exclude

This option allows you to exclude specific lines from the history (think passwords). It accepts a `Proc` which takes in the current line and must return true to exclude the line, and false to keep it.

```crystal
reader = term::reader.new(history_exclude = ->(line : String) { ... })
```

## Contributing

1. Fork it (<https://github.com/crystal-term/reader/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run the specs and make sure they pass (`crystal spec`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

## Contributors

- [Chris Watson](https://github.com/watzon) - creator and maintainer
