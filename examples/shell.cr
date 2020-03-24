require "../src/reader"

puts "*** Term::Reader Shell ***"
puts "Press Ctrl-X to exit"

reader = Term::Reader.new

reader.on_key(:ctrl_x) { puts "Exiting..."; exit }

loop do
  cmd = reader.read_line("=> ")
  puts `#{cmd}`
end
