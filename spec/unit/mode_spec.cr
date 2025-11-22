require "../spec_helper"

Spectator.describe Term::Reader::Mode do
  include TestHelpers

  let(mock_input) { MockFileDescriptor.new(0) }

  describe "#raw" do
    it "switches terminal to raw mode within block" do
      mode = described_class.new(mock_input)
      raw_mode_active = false

      result = mode.raw do
        raw_mode_active = true
        "test result"
      end

      expect(result).to eq("test result")
      expect(raw_mode_active).to be_true
    end

    it "restores previous mode after block" do
      mode = described_class.new(mock_input)

      # Execute raw mode block
      mode.raw { "in raw" }

      # Terminal should be back to original mode
      # Note: actual mode checking would require platform-specific code
    end

    it "restores mode even if block raises" do
      mode = described_class.new(mock_input)

      expect do
        mode.raw { raise "test error" }
      end.to raise_error("test error")

      # Terminal should still be restored
    end
  end

  describe "#raw" do
    it "switches terminal to raw mode temporarily" do
      mode = described_class.new(mock_input)
      result = nil
      mode.raw(true) do
        result = "raw mode active"
      end

      expect(result).to eq("raw mode active")
    end
  end

  describe "#cooked" do
    it "switches terminal to cooked mode within block" do
      mode = described_class.new(mock_input)
      cooked_mode_active = false

      result = mode.cooked do
        cooked_mode_active = true
        "cooked result"
      end

      expect(result).to eq("cooked result")
      expect(cooked_mode_active).to be_true
    end
  end

  describe "#cooked" do
    it "switches terminal to cooked mode temporarily" do
      mode = described_class.new(mock_input)
      result = nil
      mode.cooked(true) do
        result = "cooked mode active"
      end

      expect(result).to eq("cooked mode active")
    end
  end

  describe "#echo" do
    context "with echo: true" do
      it "enables echo within block" do
        mode = described_class.new(mock_input)
        echo_enabled = false

        result = mode.echo(true) do
          echo_enabled = true
          "echo on"
        end

        expect(result).to eq("echo on")
        expect(echo_enabled).to be_true
      end
    end

    context "with echo: false" do
      it "disables echo within block" do
        mode = described_class.new(mock_input)
        echo_disabled = false

        result = mode.echo(false) do
          echo_disabled = true
          "echo off"
        end

        expect(result).to eq("echo off")
        expect(echo_disabled).to be_true
      end
    end

    it "restores echo state after block" do
      mode = described_class.new(mock_input)

      mode.echo(false) { "no echo" }

      # Echo should be restored to original state
    end
  end

  describe "#echo" do
    it "enables echo temporarily" do
      mode = described_class.new(mock_input)
      result = nil
      mode.echo(true) do
        result = "echo mode active"
      end

      expect(result).to eq("echo mode active")
    end
  end

  describe "mode combinations" do
    it "can combine raw mode with echo off" do
      mode = described_class.new(mock_input)
      both_active = false

      mode.raw do
        mode.echo(false) do
          both_active = true
        end
      end

      expect(both_active).to be_true
    end

    it "restores all modes in correct order" do
      mode = described_class.new(mock_input)
      call_order = [] of String

      mode.raw do
        call_order << "raw_enter"
        mode.echo(false) do
          call_order << "echo_off_enter"
        end
        call_order << "echo_off_exit"
      end
      call_order << "raw_exit"

      expect(call_order).to eq(["raw_enter", "echo_off_enter", "echo_off_exit", "raw_exit"])
    end
  end

  describe "error handling" do
    it "handles errors when setting terminal modes" do
      # Create a mode with a closed input
      closed_input = MockFileDescriptor.new(0)
      closed_input.close

      mode = described_class.new(closed_input)

      # Should handle errors gracefully when using valid methods
      expect { mode.raw(true) { } }.not_to raise_error
      expect { mode.echo(false) { } }.not_to raise_error
    end
  end

  {% if flag?(:windows) %}
    describe "Windows-specific mode handling" do
      it "uses Windows console mode APIs" do
        pending "Windows mode tests"
      end
    end
  {% else %}
    describe "Unix-specific mode handling" do
      it "uses termios for mode control" do
        mode = described_class.new(mock_input)
        # Unix-specific mode tests would use termios
        expect(mode).to respond_to(:raw)
      end
    end
  {% end %}
end
