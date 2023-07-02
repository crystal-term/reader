module Term
  class Reader
    class Line
      ANSI_MATCHER = /(\[)?\033(\[)?[;?\d]*[\dA-Za-z](\])?/

      enum Mode
        Edit
        Replace
      end

      # Strip ANSI characters from the text
      def self.sanitize(text : String) : String
        text.gsub(ANSI_MATCHER, "")
      end

      # The editable text
      getter text : String

      # The current cursor position witin the text
      getter cursor : Int32

      # The line mode
      getter mode : Mode

      # The prompt displayed before input
      getter prompt : String

      # Create a Line instance
      def initialize(@text : String = "", @prompt : String = "")
        @cursor = [0, @text.size].max
        @mode = Mode::Edit
      end

      # ditto
      def self.new(**options, & : self ->)
        line = new(**options)
        yield line
        line
      end

      # Check if line is in edit mode
      def editing? : Bool
        @mode.edit?
      end

      # Enable edit mode
      def edit_mode : Nil
        @mode = Mode::Edit
      end

      # Check if line is in replace mode
      def replacing? : Bool
        @mode.replace?
      end

      # Enable replace mode
      def replace_mode : Nil
        @mode = Mode::Replace
      end

      # Check if cursor reached beginning of the line
      def start? : Bool
        @cursor.zero?
      end

      # Check if cursor reached end of the line
      def end? : Bool
        @cursor == @text.size
      end

      # Move line position to the left by n chars
      def left(n = 1) : Nil
        @cursor = [0, @cursor - n].max
      end

      # Move line position to the right by n chars
      def right(n = 1) : Nil
        @cursor = [@text.size, @cursor + n].min
      end

      # Move cursor to beginning position
      def move_to_start : Nil
        @cursor = 0
      end

      # Move cursor to end position
      def move_to_end : Nil
        @cursor = @text.size # put cursor outside of text
      end

      # Insert characters inside a line. When the lines exceeds
      # maximum length, an extra space is added to accomodate index.
      #
      # ```
      # text = "aaa"
      # line[5] = "b"
      # => "aaa  b"
      # ```
      def []=(i : Int, chars : String)
        edit_mode

        if i <= 0
          before_text = ""
          after_text = @text
        elsif i > @text.size - 1 # insert outside of line input
          before_text = @text
          after_text = " " * (i - @text.size)
          @cursor += after_text.size
        else
          before_text = @text[0..i - 1]
          after_text = @text[i..-1]
        end

        if i > @text.size - 1
          @text = before_text + after_text + chars
        else
          @text = before_text + chars + after_text
        end

        @cursor = i + chars.size
      end

      # Insert characters inside a line. When the lines exceeds
      # maximum length, an extra space is added to accomodate index.
      def []=(range : Range, chars : String)
        @text = @text.sub(range, chars)
        @cursor += chars.size
      end

      # Read character
      def [](i)
        @text[i]
      end

      # Replace current line with new text
      def replace(text : String)
        @text = text
        @cursor = @text.size # put cursor outside of text
        replace_mode
      end

      # Insert char(s) at cursor position
      def insert(chars)
        self[@cursor] = chars
      end

      # Add char and move cursor
      def <<(char)
        @text << char
        @cursor += 1
      end

      # Remove char from the line at current position
      def delete(n : Int32 = 1) : Nil
        stop = [@cursor + n, @text.size].min
        @text = @text.sub(@cursor...stop, "")
      end

      # Remove char from the line in front of the cursor
      def remove(n : Int32 = 1) : Nil
        left(n)
        stop = [@cursor + n, @text.size].min
        @text = @text.sub(@cursor...stop, "")
      end

      # Full line with prompt as string
      def to_s : String
        "#{@prompt}#{@text}"
      end

      def inspect : String
        to_s
      end

      # Prompt size
      def prompt_size : Int32
        p = self.class.sanitize(@prompt).split(/\r?\n/)
        # return the length of each line + screen width for every line past the first
        # which accounts for multi-line prompts
        p.join.size + ((p.size - 1) * Term::Screen.width)
      end

      # Text size
      def text_size : Int32
        self.class.sanitize(@text).size
      end

      # Full line size with prompt
      def size : Int32
        prompt_size + text_size
      end
    end # Line
  end   # Reader
end     # Term
