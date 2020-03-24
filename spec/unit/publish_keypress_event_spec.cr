require "../spec_helper"

# TODO: Figure out how to mock STDIN and STDOUT

# Spectator.describe Term::Reader do
#   describe "#publish_keypress_event" do
#     let(:input) { STDIN   }
#     let(:output) { STDOUT }
#     let(:env) { { "TTY_TEST" => "true" } }

#     let(:reader) { described_class.new(input: input, output: output, env: env) }

#     it "publishes keypress events" do
#       input << "abc\n"
#       input.rewind
#       chars = [] of String
#       lines = [] of String
#       reader.keypress.on { |event| chars << event.value; lines << event.line }
#       answer = reader.read_line

#       expect(chars).to eq(%w(a b c \n))
#       expect(lines).to eq(%w(a ab abc abc\n))
#       expect(answer).to eq("abc\n")
#     end
#   end
# end
