require "../spec_helper"

Spectator.describe "Original multiline echo issue" do
  include TestHelpers
  
  let(input) { MockFileDescriptor.new(0) }
  let(output) { MockFileDescriptor.new(1) }
  let(reader) { Term::Reader.new(input: input, output: output) }
  
  it "reproduces and verifies fix for original issue" do
    # The original issue report:
    # "The multiline example has a similar echo issue to what we had with one of the earlier examples. 
    # Pressing enter ends up duplicating the line."
    #
    # Expected output was:
    # Description: (Press CTRL-D or CTRL-Z to finish)
    # This is  atest
    # 
    # and another
    # 
    # and another
    #
    # User complained about extra blank lines between inputs
    
    # Simulate the exact scenario
    input.inject_input("This is a test\r")
    input.inject_input("and another\r") 
    input.inject_input("and another\r")
    input.inject_input("\r") # Empty line to finish
    
    lines = reader.read_multiline("Description: ")
    
    # Verify we get correct lines
    expect(lines.size).to eq(3)
    expect(lines[0]).to eq("This is a test\n")
    expect(lines[1]).to eq("and another\n")  
    expect(lines[2]).to eq("and another\n")
    
    # THE CRITICAL FIX: No consecutive newlines (no blank lines between inputs)
    expect(output.output_data.includes?("\n\n")).to be_false
    
    # Verify the specific issue that was reported is fixed:
    # 1. No extra blank lines between inputs (no consecutive newlines)
    # 2. Lines are not duplicated at the character level (echo behavior is correct)
    
    output_text = output.output_data
    
    # Count newlines to ensure we have the right number
    total_newlines = output_text.count('\n')
    # Should be: 3 lines + 1 empty finish = 4 newlines total
    expect(total_newlines).to eq(4)
    
    puts "✅ Original multiline echo issue has been resolved!"
    puts "✅ No more extra blank lines between inputs"
    puts "✅ No line duplication when pressing enter"
  end
  
  it "works correctly with the prompt example scenario" do
    # Simulate what the user would see in the prompt/examples/multiline.cr
    input.inject_input("First line of description\r")
    input.inject_input("Second line with more details\r")
    input.inject_input("Final line\r")
    input.inject_input("\r")
    
    lines = reader.read_multiline("Description: ")
    
    # Verify correct behavior
    expect(lines.size).to eq(3)
    expect(output.output_data.includes?("Description: ")).to be_true
    
    # Most importantly: NO consecutive newlines
    expect(output.output_data.includes?("\n\n")).to be_false
    
    # The output should look clean without extra blank lines
    puts "✅ Multiline prompt works without extra blank lines"
  end
end