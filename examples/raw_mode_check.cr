require "../src/term-reader"

reader = Term::Reader.new
puts "Press any single key (should register WITHOUT pressing Enter):"
key = reader.read_keypress
puts "\ngot: #{key.inspect}"
