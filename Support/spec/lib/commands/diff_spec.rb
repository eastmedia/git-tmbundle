require File.dirname(__FILE__) + '/../../spec_helper'

describe Git do
  before(:each) do
    @diff = Git.new
  end
  include SpecHelpers
  describe "when parsing a diff" do
    before(:each) do
      @results = @diff.parse_diff(fixture_file("changed_files.diff"))
      @lines = @results.first[:lines]
    end
    
    it "should create an entry for each file" do
      @results.should have(2).results
      @results.map{|r| r[:left][:filepath]}.should == ["Support/lib/commands/diff.rb", "Support/lib/formatters/diff.rb"]
      @results.map{|r| r[:right][:filepath]}.should == ["Support/lib/commands/diff.rb", "Support/lib/formatters/diff.rb"]
    end
    
    it "should parse the line_numbers for the files" do
      @lines.map{|l| l[:ln_left]}.should == 
        (5..7).to_a + 
        [8] + 
        ([nil] * 20) + 
        (9..10).to_a + 
        ["EOF"]
      
      @lines.map{|r| r[:ln_right]}.should == 
        (5..7).to_a + 
        [nil] + 
        (8..27).to_a + 
        (28..29).to_a + 
        ["EOF"]
    end
    
    it "shouldn't count the (\\ No newline at end of file) line" do
      @lines.last[:text].should == "No newline at end of file"
      @lines.last[:ln_right].should == "EOF"
      @lines.last[:ln_left].should == "EOF"
    end
  end
  
  describe "when parse a diff with line breaks" do
    before(:each) do
      @results = @diff.parse_diff(fixture_file("changed_files_with_break.diff"))
      @lines = @results.first[:lines]
    end
    
    it "should insert a line break" do
      @lines.map{|t| t[:type]}.should include(:cut)
    end
  end
  describe "when parse a diff with line breaks" do
    before(:each) do
      @results = @diff.parse_diff(fixture_file("new_line_at_end.diff"))
      @lines = @results.first[:lines]
    end
    
    it "should show EOF as occuring for the side that previously had line-numbers" do
      eof_line = @lines.find{|l| l[:type]==:eof}
      eof_line[:ln_left].should == "EOF"
      eof_line[:ln_right].should == nil
    end
  end
  
  describe "when parsing small diff" do
    before(:each) do
      @results = @diff.parse_diff(fixture_file("small.diff"))
      @lines = @results.first[:lines]
    end
    
    it "should start with line-number-zero" do
      @lines.map{|l| l[:ln_left]}.should  == [1, "EOF", nil, nil, nil, nil]
      @lines.map{|l| l[:ln_right]}.should == [nil, nil, 1,   2,   3,   "EOF"]
    end
  end
end
