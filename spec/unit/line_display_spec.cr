require "../spec_helper"

Spectator.describe Term::Reader::Line do
  describe "#to_s" do
    it "returns prompt and text combined" do
      line = Term::Reader::Line.new("", prompt: "Prompt> ")
      expect(line.to_s).to eq("Prompt> ")
    end
    
    it "returns empty string when both prompt and text are empty" do
      line = Term::Reader::Line.new("", prompt: "")
      expect(line.to_s).to eq("")
    end
    
    it "includes inserted text" do
      line = Term::Reader::Line.new("", prompt: "> ")
      line.insert("hello")
      expect(line.to_s).to eq("> hello")
    end
    
    it "includes newline when inserted" do
      line = Term::Reader::Line.new("", prompt: "")
      line.insert("hello")
      line.insert("\n")
      expect(line.to_s).to eq("hello\n")
    end
  end
  
  describe "#text" do
    it "returns only the text without prompt" do
      line = Term::Reader::Line.new("", prompt: "Prompt> ")
      line.insert("hello")
      expect(line.text).to eq("hello")
    end
    
    it "includes newline characters in text" do
      line = Term::Reader::Line.new("", prompt: "")
      line.insert("hello")
      line.insert("\n")
      expect(line.text).to eq("hello\n")
    end
  end
end