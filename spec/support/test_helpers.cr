# Test helpers and utilities for Term::Reader specs

module TestHelpers
  # Mock IO that simulates terminal input/output
  class MockTerminal < IO
    property input_buffer : Array(Char) = [] of Char
    property output_buffer : String = ""
    property? closed : Bool = false
    property read_timeout : Time::Span? = nil
    property mode : Symbol = :cooked
    
    def initialize(@input : Array(String) = [] of String)
      @input.each do |str|
        @input_buffer.concat(str.chars)
      end
    end
    
    def read(slice : Bytes) : Int32
      return 0 if @closed || @input_buffer.empty?
      
      bytes_read = 0
      slice.each_with_index do |_, i|
        break if @input_buffer.empty?
        char = @input_buffer.shift
        slice[i] = char.ord.to_u8
        bytes_read += 1
      end
      
      bytes_read
    end
    
    def write(slice : Bytes) : Nil
      @output_buffer += String.new(slice)
    end
    
    def close : Nil
      @closed = true
    end
    
    def fd : Int32
      -1
    end
    
    def blocking : Bool
      true
    end
    
    def blocking=(value : Bool)
      # no-op for mock
    end
    
    def read_timeout=(timeout : Time::Span?)
      @read_timeout = timeout
    end
    
    def cooked!
      @mode = :cooked
    end
    
    def raw!
      @mode = :raw
    end
    
    def echo!
      @mode = :echo
    end
    
    def tty?
      true
    end
    
    # Add more characters to the input buffer
    def inject_input(str : String)
      @input_buffer.concat(str.chars)
    end
    
    # Clear the output buffer and return its contents
    def consume_output : String
      output = @output_buffer
      @output_buffer = ""
      output
    end
  end
  
  # Helper to create key sequences
  module Keys
    ESC = "\e"
    
    def self.up
      "#{ESC}[A"
    end
    
    def self.down
      "#{ESC}[B"
    end
    
    def self.right
      "#{ESC}[C"
    end
    
    def self.left
      "#{ESC}[D"
    end
    
    def self.home
      "#{ESC}[H"
    end
    
    def self.end_key
      "#{ESC}[F"
    end
    
    def self.delete
      "#{ESC}[3~"
    end
    
    def self.backspace
      "\b"
    end
    
    def self.tab
      "\t"
    end
    
    def self.enter
      "\r"
    end
    
    def self.ctrl(letter : Char)
      (letter.upcase.ord - 64).chr
    end
    
    def self.alt(letter : Char)
      "#{ESC}#{letter}"
    end
    
    def self.f(num : Int32)
      case num
      when 1 then "#{ESC}OP"
      when 2 then "#{ESC}OQ"
      when 3 then "#{ESC}OR"
      when 4 then "#{ESC}OS"
      when 5 then "#{ESC}[15~"
      when 6 then "#{ESC}[17~"
      when 7 then "#{ESC}[18~"
      when 8 then "#{ESC}[19~"
      when 9 then "#{ESC}[20~"
      when 10 then "#{ESC}[21~"
      when 11 then "#{ESC}[23~"
      when 12 then "#{ESC}[24~"
      else
        raise "Unsupported F key: F#{num}"
      end
    end
  end
  
  # Helper to create a mock file descriptor
  class MockFileDescriptor < IO::FileDescriptor
    property input_data : String = ""
    property output_data : String = ""
    property read_pos : Int32 = 0
    property? blocking_mode : Bool = true
    
    def initialize(fd : Int32 = 0)
      super(fd, blocking: true)
    end
    
    
    def blocking : Bool
      @blocking_mode
    end
    
    def blocking=(value : Bool)
      @blocking_mode = value
    end
    
    def read(slice : Bytes) : Int32
      return 0 if @read_pos >= @input_data.size
      
      bytes_to_read = Math.min(slice.size, @input_data.size - @read_pos)
      return 0 if bytes_to_read == 0
      
      @input_data.to_slice[@read_pos, bytes_to_read].copy_to(slice.to_unsafe, bytes_to_read)
      @read_pos += bytes_to_read
      bytes_to_read
    end
    
    def read_char : Char?
      return nil if @read_pos >= @input_data.size
      char = @input_data[@read_pos]
      @read_pos += 1
      char
    end
    
    def write(slice : Bytes) : Nil
      @output_data += String.new(slice)
      nil
    end
    
    def print(*args)
      args.each { |arg| @output_data += arg.to_s }
      nil
    end
    
    def puts(*args)
      if args.empty?
        @output_data += "\n"
      else
        args.each { |arg| @output_data += arg.to_s + "\n" }
      end
      nil
    end
    
    def close
      @closed = true
      nil
    end
    
    def closed? : Bool
      @closed
    end
    
    def reset
      @input_data = ""
      @output_data = ""
      @read_pos = 0
    end
    
    def inject_input(data : String)
      @input_data += data
    end
    
    def tty? : Bool
      true
    end
    
    def cooked : Nil
      # No-op for testing
    end
    
    def cooked! : Nil
      # No-op for testing
    end
    
    def raw : Nil  
      # No-op for testing
    end
    
    def raw! : Nil
      # No-op for testing
    end
    
    def echo=(value : Bool) : Nil
      # No-op for testing
    end
    
    def sync? : Bool
      true
    end
    
    def sync=(value : Bool)
      # No-op for testing
    end
    
    def noecho(&block)
      yield
    end
    
    def raw(&block)
      yield
    end
    
    def cooked(&block)
      yield
    end
  end
  
  # Helper to capture events
  class EventCapture
    property events : Array({String, Term::Reader::KeyEvent}) = [] of {String, Term::Reader::KeyEvent}
    
    def handler
      ->(name : String, event : Term::Reader::KeyEvent) {
        @events << {name, event}
        nil
      }
    end
    
    def clear
      @events.clear
    end
    
    def has_event?(name : String) : Bool
      @events.any? { |n, _| n == name }
    end
    
    def event_count(name : String) : Int32
      @events.count { |n, _| n == name }
    end
  end
  
  # Platform detection helpers
  def windows?
    {% if flag?(:windows) %}
      true
    {% else %}
      false
    {% end %}
  end
  
  def unix?
    !windows?
  end
end