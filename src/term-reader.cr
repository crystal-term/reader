require "term-cursor"
require "term-screen"
require "cute"

require "./reader/history"
require "./reader/line"
require "./reader/key_event"
require "./reader/console"
require "./reader/version"

module Term
  class Reader
    # Raised when a user hits ctrl-c
    class InputInterrupt < Exception; end

    # Key codes
    CARRIAGE_RETURN =  13
    NEWLINE         =  10
    BACKSPACE       =   8
    DELETE          =  27

    getter input : IO::FileDescriptor
    getter output : IO::FileDescriptor
    getter env : Hash(String, String)

    # Do we want to keep a log of things as they happen
    getter? track_history : Bool

    getter console : Console
    getter cursor : Term::Cursor.class
    getter history : History

    getter interrupt : Symbol

    Cute.signal key_event(key : String, event : KeyEvent)
    Cute.signal keypress(event : KeyEvent)

    def initialize(@input : IO::FileDescriptor = STDIN,
                  @output : IO::FileDescriptor = STDOUT,
                  @env : Hash(String, String) = ENV.to_h,
                  @interrupt : Symbol = :error,
                  @track_history : Bool = true,
                  @history_cycle : Bool = false,
                  @history_exclude : String -> Bool = ->(s : String) { s.strip.empty? },
                  @history_duplicates : Bool = false)
      @console = Console.new(@input)

      @history = History.new do |h|
        h.cycle = @history_cycle
        h.duplicates = @history_duplicates
        h.exclude = @history_exclude
      end

      @stop = false
      @cursor = Term::Cursor
    end

    # Listen for specific keys (or all keys if `keys` is empty)
    def on_key(keys = [] of String | Symbol, &block : String, KeyEvent ->)
      if keys.empty?
        keypress.on do |event|
          block.call(event.key.name, event)
        end
      else
        keys.each do |key|
          key_event.on do |ek, event|
            if ek.lstrip("key") == key.to_s
              block.call(key.to_s, event)
            end
          end
        end
      end
      self
    end

    # Get input in unbuffered mode.
    def unbuffered(&block)
      buffering = @output.sync?
      # Immidiately flush output
      @output.sync = true
      yield
    ensure
      @output.sync = buffering
    end

    # Reads a keypress, including ivisible multibyte codes
    # and return a character as a String.
    #
    # Nothing is echoed to the console. This call will block for
    # a single keypress, but will not wait for Enter to be pressed.
    def read_keypress(echo = false, raw = true, nonblock = false)
      codes = unbuffered { get_codes(echo: echo, raw: raw, nonblock: nonblock) }
      char = codes ? codes.map(&.chr).join : nil

      trigger_key_event(char) if char
      char
    end

    # Get input code points
    # FIXME: Fails to handle escape '\e' all by itself
    def get_codes(codes = [] of Int32, echo = true, raw = false, nonblock = false)
      char = console.get_char(echo: true, raw: false)
      handle_interrupt if console.keys[char.to_s]? == "ctrl_c"
      return if char.nil?
      codes << char.ord

      condition = ->(escape : Array(UInt8)) do
        (codes - escape).empty? ||
        (escape - codes).empty? &&
        !(64..126).covers?(codes.last)
      end

      while console.escape_codes.any?(condition)
        char_codes = get_codes(codes: codes, echo: echo, raw: raw, nonblock: true)
        break if char_codes.nil?
      end

      codes.map(&.to_u8)
    end

    # Get a signal line from STDIN. Each key pressed is echoed
    # back to the shell. The input terminates when enter or
    # return key is pressed.
    def read_line(prompt = "", value = "", echo = true, raw = true, nonblock = false)
      line = Line.new(value, prompt: prompt)
      screen_width = Term::Screen.width

      @output.print(line.to_s)

      loop do
        codes = get_codes(echo: echo, raw: raw, nonblock: nonblock)
        break unless codes && !codes.empty?

        code = codes[0]
        char = String.new(Slice.new(codes.to_unsafe, codes.size))

        if ["ctrl_z", "ctrl_d"].includes?(console.keys[char]?.to_s)
          trigger_key_event(char, line: line.to_s)
          break
        end

        if raw && echo
          clear_display(line, screen_width)
        end

        case console.keys[char]?.to_s
        when "backspace", BACKSPACE == code
          if !line.start?
            line.left
            line.delete
          end
        when "delete", DELETE == code
          line.delete
        when /ctrl_/
          # skip
        when "up"
          line.replace(history_previous.to_s) if history_previous?
        when "down"
          line.replace(history_next? ? history_next.to_s : "")
        when "left"
          line.left
        when "right"
          line.right
        when "home"
          line.move_to_start
        when "end"
          line.move_to_end
        else
          if raw && code == CARRIAGE_RETURN
            char = "\n"
            line.move_to_end
          end
          line.insert(char)
        end

        if console.keys[char]? == "backspace" || BACKSPACE == code && echo
          if raw
            output.print("\e[1X") unless line.start?
          else
            output.print(" " + (line.start? ? "" : "\b"))
          end
        end

        # Trigger before line is printed to allow for changes
        trigger_key_event(char, line: line.to_s)

        if raw && echo
          output.print(line.to_s)
          if char == "\n"
            line.move_to_start
          elsif !line.end? # readjust the cursor position
            output.print(cursor.backward(line.text_size - line.cursor))
          end
        end

        if [CARRIAGE_RETURN, NEWLINE].includes?(code)
          output.puts unless echo
          break
        end

        if track_history? && echo
          add_to_history(line.text.strip)
        end
      end

      line.text
    end

    # Clear display for the current line input
    #
    # Handles clearing input that is longer than the current
    # terminal width, which allows copy + pasting long strings.
    def clear_display(line, screen_width = Term::Screen.width)
      total_lines = count_screen_lines(line.to_s, screen_width)
      current_line = count_screen_lines(line.prompt_size + line.cursor, screen_width)
      lines_down = total_lines - current_line

      output.print(cursor.down(lines_down)) unless lines_down.zero?
      output.print(cursor.clear_lines(total_lines))
    end

    # Count the number of screen lines the given line
    # takes up in the terminal.
    def count_screen_lines(line : String, screen_width = Term::Screen.width)
      line_size = Line.sanitize(line).size
      count_screen_lines(line_size, screen_width)
    end

    # ditto
    def count_screen_lines(size : Int, screen_width = Term::Screen.width)
      1 + [0, (size - 1) // screen_width].max
    end

    # Read multiple lines and return them as an array.
    # Skip empty lines in the returned lines array.
    # The input gathering is terminated by Ctrl+d or
    # Ctrl+z.
    def read_multiline(prompt = "")
      @stop = false
      lines = [] of String
      loop do
        line = read_line(prompt)
        break if !line || line.strip.empty?
        next if line !~ /\S/ && !@stop
        lines << line
        break if @stop
      end
      lines
    end

    # ditto
    def read_multiline(prompt = "", &block : String ->)
      # TODO: See if we can reduce code duplication here
      @stop = false
      lines = [] of String
      loop do
        line = read_line(prompt)
        break if !line || line.strip.empty?
        next if line !~ /\S/ && !@stop
        yield line
        break if @stop
      end
      lines
    end

    # Capture Ctrl+d and Ctrl+z events
    def ctrl_d
      @stop = true
    end

    def add_to_history(line)
      @history << line
    end

    def history_next?
      @history.next?
    end

    def history_next
      @history.next
      @history.get
    end

    def history_previous?
      @history.previous?
    end

    def history_previous
      line = @history.get
      @history.previous
      line
    end

    # Inspect class name and public attributes
    def inspect
      "#<#{self.class}: @input=#{input}, @output=#{output}>"
    end

    private def unpack_array(arr : Array(Int))
      io = IO::Memory.new
      arr.each do |i|
        io.write_bytes(i)
      end
      io.rewind
      io.gets_to_end
    end

    # Publish event
    private def trigger_key_event(char : String, line : String = "")
      event = KeyEvent.from(console.keys, char, line)
      key_event.emit("key#{event.key.name}", event) if event.trigger?
      key_event.emit("keypress", event)
    end

    # Handle input interrupt based on provided value
    private def handle_interrupt
      case @interrupt
      when :signal
        Process.kill(:int, Process.pid)
      when :exit
        exit(130)
      # when Proc
      #   @interrupt.call
      when :noop
        return
      else
        # Ctrl-C
        raise InputInterrupt.new("Ctrl-c was pressed")
      end
    end
  end
end
