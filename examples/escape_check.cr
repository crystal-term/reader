require "../src/term-reader"

reader = Term::Reader.new

puts "Press keys to inspect reader output. Press q to exit."

loop do
  char = reader.read_keypress
  break if char == "q"

  name = reader.console.keys[char]? || char.inspect
  puts "#{name}: #{char.inspect}"
end
