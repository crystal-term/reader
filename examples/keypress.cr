require "../src/term-reader"

def run
  puts "Press a key (or Ctrl-X to exit)"
  reader = Term::Reader.new

  loop do
    print "=> "
    char = reader.read_keypress
    #  Ctrl-x
    if "\u0018" == char
      puts "Exiting..."
      exit
    else
      puts char.inspect
    end
  end
rescue e : Term::Reader::InputInterrupt
end

run
