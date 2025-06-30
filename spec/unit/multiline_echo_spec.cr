require "../spec_helper"

Spectator.describe "Term::Reader multiline echo behavior" do
  include TestHelpers
  
  # Custom output tracker to analyze exact output
  class OutputTracker < IO::FileDescriptor
    property output_calls : Array({String, String}) = [] of {String, String}
    
    def initialize(fd : Int32)
      super(fd, blocking: true)
    end
    
    def write(slice : Bytes) : Nil
      str = String.new(slice)
      @output_calls << {"write", str}
      super
    end
    
    def print(*args)
      args.each do |arg|
        @output_calls << {"print", arg.to_s}
      end
      super
    end
    
    def puts(*args)
      if args.empty?
        @output_calls << {"puts", "\n"}
      else
        args.each do |arg|
          @output_calls << {"puts", "#{arg}\n"}
        end
      end
      super
    end
    
    def clear
      @output_calls.clear
    end
    
    def all_output : String
      @output_calls.map(&.[1]).join
    end
    
    def newline_count : Int32
      all_output.count('\n')
    end
    
    def consecutive_newlines? : Bool
      all_output.includes?("\n\n")
    end
  end
  
  let(input) { MockFileDescriptor.new(0) }
  let(output) { OutputTracker.new(1) }
  let(reader) { Term::Reader.new(input: input, output: output) }
  
  describe "multiline reading with echo" do
    it "does not produce extra blank lines between inputs" do
      # Simulate user typing two lines
      input.inject_input("First line\r")
      input.inject_input("Second line\r")
      input.inject_input("\r") # Empty line to finish
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["First line", "Second line"])
      
      # Analyze output
      puts "\nOutput calls:"
      output.output_calls.each_with_index do |(method, content), i|
        puts "  #{i}: #{method}(#{content.inspect})"
      end
      
      # There should be exactly 3 newlines:
      # 1. After "First line"
      # 2. After "Second line" 
      # 3. After the empty line
      expect(output.newline_count).to eq(3)
      
      # There should be no consecutive newlines
      expect(output.consecutive_newlines?).to be_false
    end
    
    it "handles single line input correctly" do
      input.inject_input("Single line\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["Single line"])
      expect(output.newline_count).to eq(2) # One after line, one for empty line
      expect(output.consecutive_newlines?).to be_false
    end
    
    it "handles immediate empty line (no input)" do
      input.inject_input("\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to be_empty
      expect(output.newline_count).to eq(1)
    end
    
    it "echoes characters as they are typed" do
      input.inject_input("abc\r\r")
      
      reader.read_multiline("")
      
      # Should see each character echoed
      printed_text = output.output_calls
        .select { |method, _| method == "print" }
        .map(&.[1])
        .join
      
      expect(printed_text.includes?("a")).to be_true
      expect(printed_text.includes?("b")).to be_true 
      expect(printed_text.includes?("c")).to be_true
    end
    
    it "handles backspace correctly" do
      input.inject_input("test\b\b\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["te"])
      # Backspace handling should not create extra newlines
      expect(output.consecutive_newlines?).to be_false
    end
    
    it "handles cursor movement without extra newlines" do
      input.inject_input("hello")
      input.inject_input("\e[D\e[D") # Move left twice
      input.inject_input("XX")
      input.inject_input("\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["helXXlo"])
      expect(output.consecutive_newlines?).to be_false
    end
  end
  
  describe "multiline with prompts" do
    it "shows prompt without extra newlines" do
      input.inject_input("Line 1\r\r")
      
      lines = reader.read_multiline("> ")
      
      expect(lines).to eq(["Line 1"])
      
      # Check that prompts appear correctly
      printed = output.all_output
      expect(printed.includes?("> ")).to be_true
      expect(output.consecutive_newlines?).to be_false
    end
  end
  
  describe "multiline line ending behavior" do
    it "correctly handles CRLF line endings" do
      input.inject_input("Line with CRLF\r\n\r\n")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["Line with CRLF"])
      # Should not create extra blank lines from CRLF
      expect(output.consecutive_newlines?).to be_false
    end
    
    it "correctly handles LF line endings" do
      input.inject_input("Line with LF\n\n")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["Line with LF"])
      expect(output.consecutive_newlines?).to be_false
    end
  end
  
  describe "edge cases" do
    it "handles very long lines without extra newlines" do
      long_line = "x" * 100
      input.inject_input("#{long_line}\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq([long_line])
      expect(output.consecutive_newlines?).to be_false
    end
    
    it "handles lines with special characters" do
      input.inject_input("Line with émoji 🎉\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["Line with émoji 🎉"])
      expect(output.consecutive_newlines?).to be_false
    end
  end
  
  # Test to specifically reproduce the reported issue
  describe "reported multiline echo issue" do
    it "does not duplicate lines when pressing enter" do
      # This test specifically targets the reported issue:
      # "Pressing enter ends up duplicating the line"
      
      input.inject_input("This is a test\r")
      input.inject_input("and another\r") 
      input.inject_input("and another\r")
      input.inject_input("\r")
      
      output.clear
      lines = reader.read_multiline("")
      
      expect(lines).to eq(["This is a test", "and another", "and another"])
      
      # Count how many times each line appears in output
      output_text = output.all_output
      expect(output_text.scan("This is a test").size).to eq(1)
      expect(output_text.scan("and another").size).to eq(2) # Appears twice in input
      
      # Ensure no blank lines between entries
      expect(output.consecutive_newlines?).to be_false
    end
  end
end