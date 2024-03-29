require "../src/term-reader"

def run_repl
  reader = Term::Reader.new
  loop do
    line = reader.read_line(prompt: ">> ")
    puts line
  end
rescue e : Term::Reader::InputInterrupt
  exit(0)
end

run_repl
