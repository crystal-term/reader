module Term
  class Reader
    class Mode
      def initialize(@input : IO::FileDescriptor)
      end

      # Echo given block
      def echo(is_on : Bool = true, & : ->)
        if is_on || !@input.tty?
          yield
        else
          @input.noecho { yield }
        end
      end

      # Use raw mode in the given block
      def raw(is_on : Bool = true, & : ->)
        if is_on || !@input.tty?
          yield
        else
          @input.raw { yield }
        end
      end

      # Enable character processing for the given block
      def cooked(is_on : Bool = true, & : ->)
        if is_on || !@input.tty?
          yield
        else
          @input.cooked { yield }
        end
      end
    end
  end
end
