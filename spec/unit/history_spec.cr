require "../spec_helper"

Spectator.describe Term::Reader::History do
  it "has no lines" do
    history = described_class.new
    expect(history.size).to eq(0)
  end

  it "doesn't navigate through empty buffer" do
    history = described_class.new
    expect(history.next?).to eq(false)
    expect(history.previous?).to eq(false)
  end

  it "allows to cycle through non-empty buffer" do
    history = described_class.new(3, cycle: true)
    history << "line"
    expect(history.next?).to eq(true)
    expect(history.previous?).to eq(true)
  end

  it "defaults maximum size" do
    history = described_class.new
    expect(history.max_size).to eq(512)
  end

  it "presents string representation" do
    history = described_class.new
    expect(history.to_s).to eq("[]")
  end

  it "adds items to history without overflowing" do
    history = described_class.new(3)
    history << "line #1"
    history << "line #2"
    history << "line #3"
    history << "line #4"

    expect(history.to_a).to eq(["line #2", "line #3", "line #4"])
    expect(history.index).to eq(3)
  end

  it "excludes items" do
    exclude = ->(line : String) { !!/line #[23]/.match(line) }
    history = described_class.new(exclude: exclude)
    history << "line #1"
    history << "line #2"
    history << "line #3"

    expect(history.to_a).to eq(["line #1"])
    expect(history.index).to eq(1)
  end

  it "walks backward and forward through history without cycling" do
    history = described_class.new
    history << "a"
    history << "b"
    history << "c"

    expect(history.index).to eq(3)
    expect(history.get).to be_nil

    expect(history.previous?).to be_true
    history.previous
    expect(history.get).to eq("c")

    expect(history.previous?).to be_true
    history.previous
    expect(history.get).to eq("b")

    expect(history.previous?).to be_true
    history.previous
    expect(history.get).to eq("a")

    expect(history.previous?).to be_false
    history.previous
    expect(history.get).to eq("a")

    expect(history.next?).to be_true
    history.next
    expect(history.get).to eq("b")

    expect(history.next?).to be_true
    history.next
    expect(history.get).to eq("c")

    expect(history.next?).to be_false
    history.next
    expect(history.get).to eq("c")
  end

  it "cycles through history when cycling is enabled" do
    history = described_class.new(cycle: true)
    history << "a"
    history << "b"
    history << "c"

    history.previous
    expect(history.get).to eq("c")

    history.previous
    expect(history.get).to eq("b")

    history.previous
    expect(history.get).to eq("a")

    history.previous
    expect(history.get).to eq("c")

    history.next
    expect(history.get).to eq("a")

    history.next
    expect(history.get).to eq("b")
  end
end
