require "../spec_helper"

Spectator.describe "Multiline duplication prevention" do
  include TestHelpers

  # Enhanced mock that can simulate actual keyboard Enter (CARRIAGE_RETURN=13)
  class KeyboardSimulator < MockFileDescriptor
    property key_sequence : Array(Int32) = [] of Int32
    property position : Int32 = 0

    def initialize(keys : Array(Int32))
      super(0)
      @key_sequence = keys
    end

    def read_char : Char?
      return nil if @position >= @key_sequence.size

      code = @key_sequence[@position]
      @position += 1
      code.chr
    end

    def inject_keyboard_input(text : String, use_cr : Bool = true)
      text.each_char do |char|
        @key_sequence << char.ord
      end
      # Add Enter key (CARRIAGE_RETURN=13 for actual keyboard)
      @key_sequence << (use_cr ? 13 : 10)
    end

    def inject_empty_line(use_cr : Bool = true)
      @key_sequence << (use_cr ? 13 : 10)
    end
  end

  # Output tracker that can detect line duplication patterns
  class DuplicationDetector < MockFileDescriptor
    property output_calls : Array(String) = [] of String
    property final_output : String = ""

    def initialize
      super(1)
    end

    def write(slice : Bytes) : Nil
      content = String.new(slice)
      @output_calls << content
      @final_output += content
    end

    def print(*args)
      args.each do |arg|
        content = arg.to_s
        @output_calls << content
        @final_output += content
      end
    end

    # Detect if a line appears duplicated
    def has_line_duplication?(line_content : String) : Bool
      # Look for the pattern: "content\ncontent" or "content\n\ncontent"
      pattern1 = "#{line_content}\n#{line_content}"
      pattern2 = "#{line_content}\n\n#{line_content}"

      @final_output.includes?(pattern1) || @final_output.includes?(pattern2)
    end

    # Count how many times a line appears in the output
    def line_occurrence_count(line_content : String) : Int32
      @final_output.scan(line_content).size
    end

    # Check for excessive blank lines
    def has_excessive_blank_lines? : Bool
      @final_output.includes?("\n\n\n") # Three newlines = excessive
    end

    # Get clean visual output (what user would see, ignoring ANSI codes)
    def visual_output : String
      # Remove ANSI escape sequences for easier testing
      @final_output.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
    end
  end

  describe "keyboard input simulation" do
    it "prevents line duplication with CARRIAGE_RETURN (actual keyboard)" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      # Simulate typing "hello" and pressing Enter (CR=13)
      input.inject_keyboard_input("hello", use_cr: true)
      input.inject_keyboard_input("world", use_cr: true)
      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      # Verify no duplication
      expect(output.has_line_duplication?("hello")).to be_false
      expect(output.has_line_duplication?("world")).to be_false

      # Verify each line appears exactly once in final output
      expect(output.line_occurrence_count("hello")).to eq(1)
      expect(output.line_occurrence_count("world")).to eq(1)

      # Verify no excessive blank lines
      expect(output.has_excessive_blank_lines?).to be_false
    end

    it "prevents line duplication with NEWLINE (file input)" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      # Simulate file input behavior (LF=10)
      input.inject_keyboard_input("test", use_cr: false)
      input.inject_keyboard_input("line2", use_cr: false)
      input.inject_empty_line(use_cr: false)

      lines = reader.read_multiline("")

      # Should work the same way regardless of CR vs LF
      expect(output.has_line_duplication?("test")).to be_false
      expect(output.has_line_duplication?("line2")).to be_false
      expect(output.line_occurrence_count("test")).to eq(1)
      expect(output.line_occurrence_count("line2")).to eq(1)
    end

    it "handles the original reported issue scenario" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      # Original issue: "This is a test", "and another", "and another"
      input.inject_keyboard_input("This is a test", use_cr: true)
      input.inject_keyboard_input("and another", use_cr: true)
      input.inject_keyboard_input("and another", use_cr: true)
      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      # Verify correct lines received
      expect(lines.size).to eq(3)
      expect(lines[0].strip).to eq("This is a test")
      expect(lines[1].strip).to eq("and another")
      expect(lines[2].strip).to eq("and another")

      # Verify no duplication in output
      expect(output.has_line_duplication?("This is a test")).to be_false
      expect(output.has_line_duplication?("and another")).to be_false

      # "and another" should appear exactly twice (user typed it twice)
      expect(output.line_occurrence_count("and another")).to eq(2)

      # No excessive blank lines
      expect(output.has_excessive_blank_lines?).to be_false
    end
  end

  describe "character-by-character echoing" do
    it "echoes characters during typing but doesn't duplicate on Enter" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      input.inject_keyboard_input("hi", use_cr: true)
      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      # Should see character-by-character echoing in output calls
      char_echoes = output.output_calls.count { |call| call == "h" || call == "hi" }
      expect(char_echoes).to be > 0 # Characters were echoed during typing

      # But final content should not be duplicated
      expect(output.has_line_duplication?("hi")).to be_false
      expect(output.line_occurrence_count("hi")).to eq(1)
    end
  end

  describe "edge cases" do
    it "handles empty input correctly" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      expect(lines).to be_empty
      expect(output.has_excessive_blank_lines?).to be_false
    end

    it "handles single character lines" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      input.inject_keyboard_input("a", use_cr: true)
      input.inject_keyboard_input("b", use_cr: true)
      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      expect(output.has_line_duplication?("a")).to be_false
      expect(output.has_line_duplication?("b")).to be_false
      expect(output.line_occurrence_count("a")).to eq(1)
      expect(output.line_occurrence_count("b")).to eq(1)
    end

    it "handles lines with special characters" do
      input = KeyboardSimulator.new([] of Int32)
      output = DuplicationDetector.new
      reader = Term::Reader.new(input: input, output: output)

      input.inject_keyboard_input("hello@world.com", use_cr: true)
      input.inject_keyboard_input("test-line_2", use_cr: true)
      input.inject_empty_line(use_cr: true)

      lines = reader.read_multiline("")

      expect(output.has_line_duplication?("hello@world.com")).to be_false
      expect(output.has_line_duplication?("test-line_2")).to be_false
    end
  end
end
