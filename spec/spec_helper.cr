require "../src/term-reader"
require "spectator"
require "./support/test_helpers"

Spectator.configure do |config|
  config.randomize
  
  # Ensure clean global state before each test
  config.before_each do
    Term::Reader.global_handlers.clear
  end
end
