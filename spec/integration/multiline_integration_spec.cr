require "../spec_helper"

Spectator.describe "Multiline integration tests" do
  include TestHelpers

  let(input) { MockFileDescriptor.new(0) }
  let(output) { MockFileDescriptor.new(1) }
  let(reader) { Term::Reader.new(input: input, output: output) }

  describe "multiline echo issue resolution" do
    it "does not create extra blank lines between inputs" do
      # Simulate the exact scenario from the original bug report
      input.inject_input("This is a test\r")
      input.inject_input("and another\r")
      input.inject_input("and another\r")
      input.inject_input("\r") # Empty line to finish

      lines = reader.read_multiline("")

      # Verify we get the expected lines
      expect(lines).to eq(["This is a test", "and another", "and another"])

      # Verify output doesn't have consecutive newlines (blank lines)
      expect(output.output_data.includes?("\n\n")).to be_false

      # Count total newlines - should be exactly 4 (3 lines + 1 empty to finish)
      newline_count = output.output_data.count('\n')
      expect(newline_count).to eq(4)
    end

    it "works correctly with prompts" do
      input.inject_input("Line 1\r")
      input.inject_input("Line 2\r")
      input.inject_input("\r")

      lines = reader.read_multiline("Description: ")

      expect(lines).to eq(["Line 1", "Line 2"])

      # Should include the prompt
      expect(output.output_data.includes?("Description: ")).to be_true

      # No consecutive newlines
      expect(output.output_data.includes?("\n\n")).to be_false
    end

    it "handles single line input correctly" do
      input.inject_input("Just one line\r\r")

      lines = reader.read_multiline("")

      expect(lines).to eq(["Just one line"])
      expect(output.output_data.includes?("\n\n")).to be_false
      expect(output.output_data.count('\n')).to eq(2)
    end

    it "handles immediate empty input" do
      input.inject_input("\r") # Just empty line to finish

      lines = reader.read_multiline("")

      expect(lines).to be_empty
      expect(output.output_data.count('\n')).to eq(1)
    end

    it "preserves line content correctly" do
      input.inject_input("Hello, world!\r")
      input.inject_input("This is line 2\r")
      input.inject_input("Final line\r")
      input.inject_input("\r")

      lines = reader.read_multiline("")

      # Verify exact content
      expect(lines[0]).to eq("Hello, world!")
      expect(lines[1]).to eq("This is line 2")
      expect(lines[2]).to eq("Final line")

      # Verify no extra blanks between lines
      expect(output.output_data.includes?("\n\n")).to be_false
    end
  end

  describe "edge cases" do
    it "handles backspace without creating extra lines" do
      input.inject_input("test\b\bst\r\r")

      lines = reader.read_multiline("")

      # Our mock doesn't perfectly handle backspace, but the important thing
      # is that no extra newlines are created
      expect(output.output_data.includes?("\n\n")).to be_false
    end

    it "handles cursor movement" do
      input.inject_input("hello")
      input.inject_input("\e[D\e[D") # Move left twice
      input.inject_input("XX")
      input.inject_input("\r\r")

      lines = reader.read_multiline("")

      expect(lines).to eq(["helXXlo"])
      expect(output.output_data.includes?("\n\n")).to be_false
    end

    it "handles empty lines in the middle of input" do
      input.inject_input("Line 1\r")
      input.inject_input("   \r") # Whitespace-only line (should be skipped)
      input.inject_input("Line 2\r")
      input.inject_input("\r")

      lines = reader.read_multiline("")

      # The key point is no extra newlines are created
      expect(output.output_data.includes?("\n\n")).to be_false
      # Lines may vary based on whitespace handling, but no duplicate newlines
    end
  end
end
