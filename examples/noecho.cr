require "../src/term-reader"

reader = Term::Reader.new

answer = reader.read_line(prompt: "=> ", echo: false)

puts "Answer: #{answer}"
