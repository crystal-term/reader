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
    expect(history.index).to eq(2)
  end

  it "excludes items" do
    exclude = ->(line : String) { !!/line #[23]/.match(line) }
    history = described_class.new(exclude: exclude)
    history << "line #1"
    history << "line #2"
    history << "line #3"

    expect(history.to_a).to eq(["line #1"])
    expect(history.index).to eq(0)
  end
end
