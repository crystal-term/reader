require "../src/term-reader"

reader = Term::Reader.new
reader.on_key(:ctrl_x) { puts "Exiting..."; exit(0) }

loop do
  reader.read_line(prompt: "one\ntwo\nthree")
end
