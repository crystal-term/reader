require "../src/term-reader"

reader = Term::Reader.new

answer = reader.read_line("=> ", echo: false)

puts "Answer: #{answer}"
