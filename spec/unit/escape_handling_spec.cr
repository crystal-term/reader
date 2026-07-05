require "../spec_helper"

Spectator.describe "Term::Reader escape handling" do
  PIPE_CLOSE_DELAY = 250.milliseconds

  def read_pipe_keypress(parts : Array({String, Time::Span}), close_delay : Time::Span = PIPE_CLOSE_DELAY)
    input, writer = IO.pipe
    reader = Term::Reader.new(input: input, output: IO::Memory.new)
    delayed_index = 0

    parts.each_with_index do |part, index|
      break unless part[1].zero?

      writer.write part[0].to_slice
      writer.flush
      delayed_index = index + 1
    end

    delayed_parts = parts[delayed_index, parts.size - delayed_index]
    closer = Thread.new do
      delayed_parts.each do |part|
        sleep part[1]
        writer.write part[0].to_slice
        writer.flush
      end

      sleep close_delay
      writer.close unless writer.closed?
    end

    started_at = Time.instant
    keypress = reader.read_keypress(raw: false)
    elapsed = Time.instant - started_at

    input.close unless input.closed?
    writer.close unless writer.closed?
    closer.join

    {keypress, elapsed}
  end

  it "returns a bare escape keypress after the escape timeout" do
    keypress, elapsed = read_pipe_keypress([{"\e", 0.milliseconds}])

    expect(keypress).to eq("\e")
    expect(elapsed).to be < PIPE_CLOSE_DELAY
  end

  it "reads a complete up-arrow escape sequence from one write" do
    keypress, _elapsed = read_pipe_keypress([{"\e[A", 0.milliseconds}], close_delay: 0.milliseconds)

    expect(keypress).to eq("\e[A")
  end

  it "reads a split-burst up-arrow escape sequence before the timeout" do
    keypress, _elapsed = read_pipe_keypress([
      {"\e", 0.milliseconds},
      {"[A", 5.milliseconds},
    ], close_delay: 0.milliseconds)

    expect(keypress).to eq("\e[A")
  end

  it "reads double escape as two escape bytes" do
    keypress, elapsed = read_pipe_keypress([{"\e\e", 0.milliseconds}])

    expect(keypress).to eq("\e\e")
    expect(elapsed).to be < PIPE_CLOSE_DELAY
  end

  it "still reads a fast full escape sequence without waiting for pipe close" do
    keypress, elapsed = read_pipe_keypress([{"\e[B", 0.milliseconds}], close_delay: 0.milliseconds)

    expect(keypress).to eq("\e[B")
    expect(elapsed).to be < PIPE_CLOSE_DELAY
  end
end
