require "./keys"
require "./mode"

module Term
  class Reader
    class Console
      ESC = '\e'
      CSI = "\e["

      TIMEOUT = 100.milliseconds

      getter keys : Hash(String, String)
      getter escape_codes : Tuple(Array(UInt8), Array(UInt8))

      protected getter input : IO::FileDescriptor
      protected getter mode : Mode

      def initialize(@input : IO::FileDescriptor)
        @mode = Mode.new(@input)
        @keys = CTRL_KEYS.merge(KEYS)
        @escape_codes = {[ESC.ord.to_u8], CSI.bytes}
      end

      def get_char(raw : Bool = false,
                   echo : Bool = false,
                   nonblock : Bool = false)
        ret = nil
        mode.cooked(!raw) do
          mode.raw(raw) do
            mode.echo(echo) do
              if nonblock
                @input.wait_readable(TIMEOUT)
                ret = @input.read_char
              else
                ret = @input.read_char
              end
            end
          end
        end
        ret ? ret.not_nil! : nil
      rescue
        nil
      end
    end
  end
end
