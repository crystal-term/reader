require "./keys"
require "./mode"

module Term
  class Reader
    class Console
      ESC = '\e'
      CSI = "\e["

      TIMEOUT = 100.milliseconds

      getter keys : Hash(String, String)
      getter escape_codes : Array(Array(UInt8))

      protected getter input : IO::FileDescriptor
      protected getter mode : Mode

      def initialize(@input : IO::FileDescriptor)
        @mode = Mode.new(@input)
        @keys = CONTROL_KEYS.merge(KEYS)
        @escape_codes = [[ESC.ord.to_u8], CSI.bytes, [ESC.ord.to_u8, 79_u8]]
      end

      def get_char(raw : Bool, echo : Bool, nonblock : Bool) : Char?
        char = nil
        mode.cooked(!raw) do
          mode.raw(raw) do
            mode.echo(echo) do
              @input.blocking = !nonblock
              char = @input.read_char
            end
          end
        end

        char
      rescue
        nil
      end
    end
  end
end
