require "../src/reader"

reader = Term::Reader.new

answer = reader.read_multiline(">> ")

puts "\nanswer: #{answer}"
