module Term
  class Reader
    class History
      include Enumerable(String)

      # Default maximum size
      DEFAULT_SIZE = 32 << 4

      # Default exclude proc
      EXCLUDE_NONE = ->(s : String) { false }

      @history : Array(String)
      delegate :each, :size, :length, :to_s, to: @history

      # Set and retrive the maximum size of the buffer
      property max_size : Int32

      getter index : Int32

      property cycle : Bool

      property duplicates : Bool

      property exclude : String -> Bool

      # Create a history buffer
      def initialize(@max_size : Int32 = DEFAULT_SIZE,
                     @duplicates : Bool = true,
                     @cycle : Bool = false,
                     @exclude : String -> Bool = EXCLUDE_NONE)
        @index = 0
        @history = [] of String
      end

      def self.new(**options, & : self ->)
        history = new(**options)
        yield history
        history
      end

      def push(line : String) : String
        @history.delete(line) unless duplicates
        return line if line.empty? || @exclude.call(line)

        @history.shift if size >= max_size
        @history << line
        @index = @history.size - 1

        line
      end

      def <<(line : String) : String
        push(line)
      end

      def next : Nil
        return if size.zero?
        if @index == size - 1
          @index = 0 if @cycle
        else
          @index += 1
        end
      end

      def next? : Bool
        size > 0 && !(@index == size - 1 && !@cycle)
      end

      def succ : Nil
        self.next
      end

      def previous : Nil
        return if size.zero?
        if @index.zero?
          @index = size - 1 if @cycle
        else
          @index -= 1
        end
      end

      def previous? : Bool
        size > 0 && !(@index < 0 && !cycle)
      end

      def pred : Nil
        self.previous
      end

      def [](index : Int) : String
        if index < 0
          index += @history.size
        end
        @history[index]
      end

      def get : String?
        return if size.zero?
        self[@index]
      end

      def clear : Nil
        @history.clear
        @index = 0
      end
    end
  end
end
