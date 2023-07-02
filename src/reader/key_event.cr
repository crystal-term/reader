require "./keys"

module Term
  class Reader
    # Responsible for meta-data information about key pressed
    record Key,
      name : String,
      ctrl : Bool = false,
      meta : Bool = false,
      shift : Bool = false

    # Represents key event emitted during keyboard press
    record KeyEvent, key : Key, value : String, line : String do
      def self.from(keys : Hash(String, String),
                    char : String | Char,
                    line : String = "")
        char = char.to_s
        name = keys[char]? || ""
        ctrl = false
        meta = false
        shift = false
        case char
        when /^[a-z]{1}$/
          name = "alpha"
        when /^[A-Z]{1}$/
          name = "alpha"
        when /^\d+$/
          name = "num"
        else
          if !!Reader::CTRL_KEYS[char]?
            ctrl = true
          end
        end

        key = Key.new(name, ctrl, meta, shift)
        new(key, char, line)
      end

      def trigger?
        !@key.name.empty?
      end
    end
  end
end
