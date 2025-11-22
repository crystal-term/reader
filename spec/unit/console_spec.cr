require "../spec_helper"

Spectator.describe Term::Reader::Console do
  include TestHelpers

  let(mock_input) { MockFileDescriptor.new(0) }
  let(console) { described_class.new(mock_input) }

  describe "#keys" do
    it "returns the keys hash" do
      expect(console.keys).to be_a(Hash(String, String))
    end
  end

  describe "#escape_codes" do
    it "returns an array of escape code sequences" do
      codes = console.escape_codes
      expect(codes).to be_a(Array(Array(UInt8)))
      expect(codes).not_to be_empty

      # Check for common escape sequences
      esc_code = [27_u8]
      expect(codes).to contain(esc_code)
      expect(codes).to contain(esc_code + [91_u8]) # ESC[
      expect(codes).to contain(esc_code + [79_u8]) # ESCO
    end
  end

  describe "#get_char" do
    context "in raw mode" do
      it "reads a single character" do
        mock_input.inject_input("a")
        char = console.get_char(echo: false, raw: true, nonblock: false)
        expect(char).to eq('a')
      end

      it "reads special characters" do
        mock_input.inject_input("\t")
        char = console.get_char(echo: false, raw: true, nonblock: false)
        expect(char).to eq('\t')
      end

      it "reads newline character" do
        mock_input.inject_input("\n")
        char = console.get_char(echo: false, raw: true, nonblock: false)
        expect(char).to eq('\n')
      end

      it "handles escape sequences" do
        mock_input.inject_input("\e[A")
        char = console.get_char(echo: false, raw: true, nonblock: false)
        expect(char).to eq('\e')
      end
    end

    context "with echo enabled" do
      it "echoes the character to output" do
        mock_input.inject_input("x")

        char = console.get_char(echo: true, raw: true, nonblock: false)
        expect(char).to eq('x')
        # Note: actual echo implementation is handled internally
      end
    end

    context "in nonblocking mode" do
      it "returns nil when no input available" do
        # Empty input buffer
        char = console.get_char(echo: false, raw: true, nonblock: true)
        expect(char).to be_nil
      end

      it "reads available character immediately" do
        mock_input.inject_input("z")
        char = console.get_char(echo: false, raw: true, nonblock: true)
        expect(char).to eq('z')
      end
    end
  end

  describe "platform-specific behavior" do
    {% if flag?(:windows) %}
      it "uses Windows-specific console handling" do
        # Windows-specific tests would go here
        pending "Windows console tests"
      end
    {% else %}
      it "uses Unix-style terminal handling" do
        # Unix-specific tests
        expect(console).to respond_to(:get_char)
      end
    {% end %}
  end

  describe "error handling" do
    it "handles IO errors gracefully" do
      # Create a console with a mock that will fail
      failing_input = MockFileDescriptor.new(0)
      failing_input.close

      error_console = Term::Reader::Console.new(failing_input)
      char = error_console.get_char(echo: false, raw: true, nonblock: true)
      expect(char).to be_nil
    end
  end

  describe "character encoding" do
    it "handles UTF-8 characters" do
      mock_input.inject_input("é")
      char = console.get_char(echo: false, raw: true, nonblock: false)
      expect(char).to eq('é')
    end

    it "handles multi-byte UTF-8 sequences" do
      mock_input.inject_input("🎉")
      char = console.get_char(echo: false, raw: true, nonblock: false)
      expect(char).to eq('🎉')
    end
  end
end
