require "../src/term-reader"

reader = Term::Reader.new

answer = reader.read_multiline(">> ")

puts "\nanswer: #{answer}"
