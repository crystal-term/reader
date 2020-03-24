module Term
  class Reader
    class Mode
      def initialize(@input : IO::FileDescriptor)
      end

      # Echo given block
      def echo(is_on : Bool = true, &block)
        if is_on || !@input.tty?
          yield
        else
          @input.noecho { block.call }
        end
      end

      # Use raw mode in the given block
      def raw(is_on : Bool = true, &block)
        if is_on || !@input.tty?
          yield
        else
          @input.raw { block.call }
        end
      end

      # Enable character processing for the given block
      def cooked(is_on : Bool = true, &block)
        if is_on || !@input.tty?
          yield
        else
          @input.cooked { block.call }
        end
      end
    end
  end
end
