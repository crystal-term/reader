require "../spec_helper"

# Regression tests for the multiline echo duplication issue
# These tests ensure the specific bug that was fixed doesn't come back

Spectator.describe "Multiline echo duplication regression tests" do
  include TestHelpers
  
  describe "original issue reproduction" do
    it "REGRESSION: does not duplicate lines when pressing Enter in multiline" do
      # This test specifically reproduces the exact issue reported:
      # "When I enter text and hit return I see the line I just entered, and then another line"
      
      input = MockFileDescriptor.new(0)
      output = MockFileDescriptor.new(1)
      reader = Term::Reader.new(input: input, output: output)
      
      # Simulate the exact user input that caused the issue
      input.inject_input("test line\r\r")  # CR simulates actual keyboard Enter
      
      lines = reader.read_multiline("")
      
      # Should get exactly one line back
      expect(lines.size).to eq(1)
      expect(lines[0].strip).to eq("test line")
      
      # CRITICAL: Output should NOT contain "test line" appearing twice consecutively
      output_text = output.output_data
      
      # Remove ANSI escape sequences for cleaner analysis
      clean_output = output_text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      
      # The key test: should NOT have the duplication pattern
      # Before the fix, we would see "test line" appear twice as complete lines
      # Now we should only see character-by-character echoing without duplication
      
      # Should NOT have the pattern where the complete line appears twice
      expect(clean_output.scan("test line").size).to be <= 1
      
      # More importantly, should not have immediate duplication pattern
      expect(clean_output.includes?("test line\ntest line")).to be_false
    end
    
    it "REGRESSION: does not create extra blank lines between multiline inputs" do
      # This test reproduces the extra blank line part of the issue
      
      input = MockFileDescriptor.new(0)
      output = MockFileDescriptor.new(1)
      reader = Term::Reader.new(input: input, output: output)
      
      input.inject_input("line1\rline2\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines.size).to eq(2)
      
      # Check that we don't have excessive consecutive newlines in output
      output_text = output.output_data
      clean_output = output_text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      
      # Should not have triple newlines (which would indicate extra blank lines)
      expect(clean_output.includes?("\n\n\n")).to be_false
    end
    
    it "REGRESSION: multiline with prompt works without duplication" do
      # Test with actual prompt (like the examples/multiline.cr)
      
      input = MockFileDescriptor.new(0)
      output = MockFileDescriptor.new(1)
      reader = Term::Reader.new(input: input, output: output)
      
      input.inject_input("description line\r\r")
      
      lines = reader.read_multiline("Description: ")
      
      expect(lines.size).to eq(1)
      expect(lines[0].strip).to eq("description line")
      
      # Prompt should appear but content should not be duplicated
      output_text = output.output_data
      expect(output_text.includes?("Description: ")).to be_true
      
      # Remove ANSI codes and check for duplication
      clean_output = output_text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      expect(clean_output.includes?("description line\ndescription line")).to be_false
    end
  end
  
  describe "character echo behavior" do
    it "REGRESSION: character-by-character echo works but doesn't cause final duplication" do
      input = MockFileDescriptor.new(0)
      output = MockFileDescriptor.new(1)
      reader = Term::Reader.new(input: input, output: output)
      
      input.inject_input("abc\r\r")
      
      lines = reader.read_multiline("")
      
      expect(lines.size).to eq(1)
      expect(lines[0].strip).to eq("abc")
      
      # The characters 'a', 'b', 'c' should appear in output during typing
      output_text = output.output_data
      expect(output_text.includes?("a")).to be_true
      expect(output_text.includes?("b")).to be_true  
      expect(output_text.includes?("c")).to be_true
      
      # Character-by-character echoing means we see progressive builds: "a", "ab", "abc"
      # This is expected behavior, not duplication
      clean_output = output_text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      
      # Should NOT have "abc\nabc" duplication pattern
      expect(clean_output.includes?("abc\nabc")).to be_false
    end
  end
  
  describe "newline handling" do
    it "REGRESSION: CARRIAGE_RETURN vs NEWLINE both work without duplication" do
      # Test both CR (keyboard) and LF (file) input
      
      # Test with CARRIAGE_RETURN (13) - keyboard input
      input1 = MockFileDescriptor.new(0)
      output1 = MockFileDescriptor.new(1)
      reader1 = Term::Reader.new(input: input1, output: output1)
      
      input1.inject_input("test\r\r")  # CR
      lines1 = reader1.read_multiline("")
      
      # Test with NEWLINE (10) - file input  
      input2 = MockFileDescriptor.new(0)
      output2 = MockFileDescriptor.new(1)
      reader2 = Term::Reader.new(input: input2, output: output2)
      
      input2.inject_input("test\n\n")  # LF
      lines2 = reader2.read_multiline("")
      
      # Both should work the same way
      expect(lines1.size).to eq(1)
      expect(lines2.size).to eq(1)
      expect(lines1[0].strip).to eq("test")
      expect(lines2[0].strip).to eq("test")
      
      # Neither should have duplication
      clean_output1 = output1.output_data.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      clean_output2 = output2.output_data.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
      
      expect(clean_output1.includes?("test\ntest")).to be_false
      expect(clean_output2.includes?("test\ntest")).to be_false
    end
  end
end