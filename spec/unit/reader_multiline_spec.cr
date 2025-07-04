require "../spec_helper"
require "io/memory"

Spectator.describe Term::Reader do
  describe "#read_multiline" do
    it "reads multiple lines until empty line" do
      input = IO::Memory.new("line1\nline2\n\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      lines = reader.read_multiline
      
      lines.should eq(["line1", "line2"])
    end
    
    it "reads multiple lines with echo enabled" do
      input = IO::Memory.new("line1\nline2\n\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      lines = reader.read_multiline
      
      # Check output - should not have extra blank lines
      output_str = output.to_s
      output_str.should_not contain("\n\n\n")  # No triple newlines
    end
    
    it "handles prompt correctly for first line only" do
      input = IO::Memory.new("line1\nline2\n\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      lines = reader.read_multiline("Prompt> ")
      
      output_str = output.to_s
      output_str.should start_with("Prompt> ")
      # Count occurrences of prompt - should only appear once
      output_str.scan("Prompt> ").size.should eq(1)
    end
    
    it "stops on Ctrl+D" do
      input = IO::Memory.new("line1\n\x04")  # \x04 is Ctrl+D
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      lines = reader.read_multiline
      
      lines.should eq(["line1"])
    end
    
    it "stops on Ctrl+Z" do
      input = IO::Memory.new("line1\n\x1A")  # \x1A is Ctrl+Z
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      lines = reader.read_multiline
      
      lines.should eq(["line1"])
    end
    
    it "yields each line to block" do
      input = IO::Memory.new("line1\nline2\n\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      yielded_lines = [] of String
      reader.read_multiline { |line| yielded_lines << line }
      
      yielded_lines.should eq(["line1", "line2"])
    end
  end
  
  describe "#read_line" do
    it "reads a single line" do
      input = IO::Memory.new("hello\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      line = reader.read_line
      
      line.should eq("hello")
    end
    
    it "handles prompt" do
      input = IO::Memory.new("hello\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      line = reader.read_line(prompt: "> ")
      
      output.to_s.should start_with("> ")
    end
    
    it "handles echo disabled" do
      input = IO::Memory.new("password\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      line = reader.read_line(echo: false)
      
      line.should eq("password")
      output.to_s.should_not contain("password")
    end
    
    it "removes trailing newline" do
      input = IO::Memory.new("hello\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output)
      
      line = reader.read_line
      
      line.should eq("hello")
      line.should_not end_with("\n")
    end
    
    context "with raw mode" do
      it "handles carriage return conversion to newline" do
        # In raw mode, \r should be converted to \n
        input = IO::Memory.new("hello\r")
        output = IO::Memory.new
        reader = Term::Reader.new(input: input, output: output, env: {"TTY_TEST" => "1"})
        
        line = reader.read_line(raw: true)
        
        line.should eq("hello")
      end
    end
  end
  
  describe "multiline visual output" do
    it "should not have extra blank lines between input lines" do
      # Simulate typing "line1" <enter> "line2" <enter> <enter>
      input = IO::Memory.new("line1\nline2\n\n")
      output = IO::Memory.new
      reader = Term::Reader.new(input: input, output: output, env: {"TTY_TEST" => "1"})
      
      lines = reader.read_multiline(prompt: "")
      
      # Get the output and analyze it
      output_lines = output.to_s.split('\n', remove_empty: false)
      
      # Check that we don't have consecutive empty lines
      consecutive_empty = false
      output_lines.each_cons(2) do |prev, curr|
        if prev.empty? && curr.empty?
          consecutive_empty = true
          break
        end
      end
      
      consecutive_empty.should be_false
    end
  end
end