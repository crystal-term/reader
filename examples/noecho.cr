require "../src/reader"

reader = Term::Reader.new

answer = reader.read_line("=> ", echo: false)

puts "Answer: #{answer}"
