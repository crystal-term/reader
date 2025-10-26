require "../spec_helper"

Spectator.describe Term::Reader do
  include TestHelpers
  
  let(input) { MockFileDescriptor.new(0) }
  let(output) { MockFileDescriptor.new(1) }
  let(reader) { described_class.new(input: input, output: output) }
  
  describe "#initialize" do
    it "creates reader with default settings" do
      r = described_class.new
      expect(r.input).to eq(STDIN)
      expect(r.output).to eq(STDOUT)
      expect(r.track_history?).to be_true
      expect(r.interrupt).to eq(:error)
    end
    
    it "accepts custom input/output" do
      r = described_class.new(input: input, output: output)
      expect(r.input).to eq(input)
      expect(r.output).to eq(output)
    end
    
    it "accepts interrupt mode" do
      r = described_class.new(interrupt: :exit)
      expect(r.interrupt).to eq(:exit)
    end
    
    it "accepts history settings" do
      r = described_class.new(
        track_history: false,
        history_cycle: true,
        history_duplicates: true
      )
      expect(r.track_history?).to be_false
    end
  end
  
  describe "#read_keypress" do
    it "reads a single keypress" do
      input.inject_input("a")
      char = reader.read_keypress
      expect(char).to eq("a")
    end
    
    it "reads special keys" do
      input.inject_input("\t")
      char = reader.read_keypress
      expect(char).to eq("\t")
    end
    
    it "reads escape sequences" do
      input.inject_input("\e[A")
      char = reader.read_keypress
      expect(char).to eq("\e[A")
    end
    
    it "does not echo by default" do
      input.inject_input("x")
      reader.read_keypress
      expect(output.output_data).to be_empty
    end
    
    it "echoes when echo: true" do
      input.inject_input("y")
      reader.read_keypress(echo: true)
      expect(output.output_data).to eq("y")
    end
    
    it "returns nil in nonblocking mode with no input" do
      char = reader.read_keypress(nonblock: true)
      expect(char).to be_nil
    end
    
    it "handles ctrl+c with interrupt mode" do
      input.inject_input("\x03") # Ctrl+C
      
      # Test different interrupt modes
      r_error = described_class.new(input: input, interrupt: :error)
      expect { r_error.read_keypress }.to raise_error(Term::Reader::InputInterrupt)
      
      input.reset
      input.inject_input("\x03")
      r_noop = described_class.new(input: input, interrupt: :noop)
      char = r_noop.read_keypress
      expect(char).to eq("\x03")
    end
  end
  
  describe "#read_line" do
    it "reads a line until enter" do
      input.inject_input("hello\r")
      line = reader.read_line
      expect(line).to eq("hello")
    end
    
    it "reads with custom prompt" do
      input.inject_input("world\r")
      line = reader.read_line(prompt: "> ")
      expect(line).to eq("world")
      expect(output.output_data.includes?("> ")).to be_true
    end
    
    it "handles initial value" do
      input.inject_input("\r")
      line = reader.read_line(value: "default")
      expect(line).to eq("default")
    end
    
    it "handles backspace" do
      input.inject_input("test\b\b\r")
      line = reader.read_line
      expect(line).to eq("te")
    end
    
    it "handles arrow keys for navigation" do
      input.inject_input("hello")
      input.inject_input("\e[D") # left arrow
      input.inject_input("\e[D") # left arrow
      input.inject_input("X")
      input.inject_input("\r")
      line = reader.read_line
      expect(line).to eq("helXlo")
    end
    
    it "handles home and end keys" do
      input.inject_input("test")
      input.inject_input("\e[H") # home
      input.inject_input("X")
      input.inject_input("\e[F") # end
      input.inject_input("Y")
      input.inject_input("\r")
      line = reader.read_line
      expect(line).to eq("XtestY")
    end
    
    it "handles delete key" do
      input.inject_input("test")
      input.inject_input("\e[D") # left arrow
      input.inject_input("\e[3~") # delete
      input.inject_input("\r")
      line = reader.read_line
      expect(line).to eq("tes")
    end
    
    it "handles ctrl+d to exit" do
      input.inject_input("partial\x04") # Ctrl+D
      line = reader.read_line
      expect(line).to eq("partial")
    end
    
    it "handles ctrl+z to exit" do
      input.inject_input("partial\x1a") # Ctrl+Z
      line = reader.read_line
      expect(line).to eq("partial")
    end
    
    context "with echo disabled" do
      it "does not echo input" do
        input.inject_input("secret\r")
        line = reader.read_line(echo: false)
        expect(line).to eq("secret")
        # Output should only have prompt and newline, not the input
        expect(output.output_data.includes?("secret")).to be_false
      end
    end
    
    context "with history" do
      it "navigates history with up/down arrows" do
        # Add some history
        reader.add_to_history("first")
        reader.add_to_history("second")
        
        # Navigate history
        input.inject_input("\e[A") # up arrow
        input.inject_input("\r")
        line = reader.read_line
        expect(line).to eq("second")
      end
      
      it "tracks history when enabled" do
        r = described_class.new(input: input, output: output, track_history: true)
        input.inject_input("tracked\r")
        r.read_line
        
        expect(r.history.to_a.includes?("tracked")).to be_true
      end
      
      it "does not track history when disabled" do
        r = described_class.new(input: input, output: output, track_history: false)
        input.inject_input("not tracked\r")
        r.read_line
        
        expect(r.history.to_a).to be_empty
      end
    end
  end
  
  describe "#read_multiline" do
    it "reads multiple lines until empty line" do
      input.inject_input("line1\r\r")
      lines = reader.read_multiline
      expect(lines).to eq(["line1"])
    end
    
    it "reads multiple lines with content" do
      input.inject_input("line1\rline2\rline3\r\r")
      lines = reader.read_multiline
      expect(lines).to eq(["line1", "line2", "line3"])
    end
    
    it "yields each line to block" do
      input.inject_input("first\rsecond\r\r")
      yielded_lines = [] of String
      
      lines = reader.read_multiline do |line|
        yielded_lines << line
      end
      
      expect(yielded_lines).to eq(["first", "second"])
      expect(lines).to eq(["first", "second"])
    end
    
    it "stops on ctrl+d" do
      input.inject_input("line1\rline2\r\x04")
      lines = reader.read_multiline
      expect(lines).to eq(["line1", "line2"])
    end
    
    it "stops on ctrl+z" do
      input.inject_input("line1\rline2\r\x1a")
      lines = reader.read_multiline
      expect(lines).to eq(["line1", "line2"])
    end
    
    it "skips whitespace-only lines" do
      input.inject_input("line1\r   \rline2\r\r")
      lines = reader.read_multiline
      expect(lines).to eq(["line1", "line2"])
    end
    
    it "uses custom prompt" do
      input.inject_input("test\r\r")
      reader.read_multiline(">> ")
      expect(output.output_data.includes?(">> ")).to be_true
    end
  end
  
  describe "#get_codes" do
    it "reads single character codes" do
      input.inject_input("a")
      codes = reader.get_codes(echo: false, raw: true, nonblock: false)
      expect(codes).to eq([97]) # 'a'
    end
    
    it "reads escape sequence codes" do
      input.inject_input("\e[A")
      codes = reader.get_codes(echo: false, raw: true, nonblock: false)
      expect(codes).to eq([27, 91, 65]) # ESC [ A
    end
    
    it "handles incomplete escape sequences" do
      input.inject_input("\e")
      codes = reader.get_codes(echo: false, raw: true, nonblock: false)
      expect(codes).to eq([27])
    end
    
    it "returns nil on empty input in nonblocking mode" do
      codes = reader.get_codes(echo: false, raw: true, nonblock: true)
      expect(codes).to be_nil
    end
  end
  
  describe "#on_key" do
    it "registers key handlers" do
      handled = false
      reader.on_key(:enter) { |name, event| handled = true; nil }
      
      input.inject_input("\r")
      reader.read_keypress
      
      expect(handled).to be_true
    end
    
    it "registers handlers for multiple keys" do
      keys_pressed = [] of String
      reader.on_key(:up, :down) do |name, event|
        keys_pressed << name
        nil
      end
      
      input.inject_input("\e[A") # up
      reader.read_keypress
      input.inject_input("\e[B") # down
      reader.read_keypress
      
      expect(keys_pressed).to eq(["up", "down"])
    end
    
    it "registers catch-all handler" do
      all_keys = [] of String
      reader.on_key do |name, event|
        all_keys << name
        nil
      end
      
      input.inject_input("a")
      reader.read_keypress
      input.inject_input("\t")
      reader.read_keypress
      
      expect(all_keys.includes?("a")).to be_true
      expect(all_keys.includes?("tab")).to be_true
    end
  end
  
  describe "#unbuffered" do
    it "executes block in unbuffered mode" do
      result = reader.unbuffered do
        "unbuffered result"
      end
      
      expect(result).to eq("unbuffered result")
    end
    
    it "restores buffering after block" do
      original_sync = output.sync?
      
      reader.unbuffered { "test" }
      
      expect(output.sync?).to eq(original_sync)
    end
    
    it "handles sync? returning nil without type errors" do
      mock_output = MockFileDescriptor.new(1)
      mock_output.sync_value = nil
      r = described_class.new(input: input, output: mock_output)
      
      executed = false
      expect do
        r.unbuffered do
          executed = true
        end
      end.not_to raise_error
      
      expect(executed).to be_true
    end
  end
  
  describe "#inspect" do
    it "returns inspection string" do
      inspection = reader.inspect
      expect(inspection.includes?("Term::Reader")).to be_true
      expect(inspection.includes?("@input=")).to be_true
      expect(inspection.includes?("@output=")).to be_true
    end
  end
end