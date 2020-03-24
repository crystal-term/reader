require "../src/reader"

def run_repl
  reader = Term::Reader.new
  loop do
    line = reader.read_line(">> ")
    puts line
  end
rescue e : Term::Reader::InputInterrupt
  exit(0)
end

run_repl
