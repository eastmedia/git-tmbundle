require File.dirname(__FILE__) + '/../spec_helper'

describe RemoteController do
  include SpecHelpers
  include Parsers
  
  before(:each) do
    Git.reset_mock!
    @git = Git.singleton_new
  end
  
  describe "fetching" do
    before(:each) do
      # query the sources
      @git.config.stub!(:[]).with("branch.master.remote").and_return("origin")
      Git.command_response["branch"] = "* master\n"
      Git.command_response["config", "branch.master.remote"] = %Q{origin}
      Git.command_response["remote"] = %Q{origin}
      
      git = Git.singleton_new
      git.should_receive(:log).with({:path=>".", :revisions=>["74c0fdf", "d1c6bdd"]}).and_return(parse_log(fixture_file("log_with_diffs.txt")))
      
      Git.command_response["fetch", "origin"] = fixture_file("fetch_1_5_4_3_output.txt")
      
      @output = capture_output do
        dispatch :controller => "remote", :action => "fetch"
      end
    end
    
    it "should use javascript to output the progress" do
      @output.should include("$('Compressing_progress').update('Done')")
    end
    
    it "should output a log" do
      @output.should include("<h2>Log of changes fetched</h2>")
      @output.should include("<h2>Branch 'asdf': 74c0fdf..d1c6bdd</h2>")
      @output.should include("tim@email.com")
    end
  end
  
  describe "pulling" do
    before(:each) do
      # query the sources
      Git.command_response["branch"] = "* master\n"
      Git.command_response["branch", "-r"] = "  origin/master\n  origin/release\n"
      @git.config.stub!(:[]).with("remote.origin.fetch").and_return("+refs/heads/*:refs/remotes/origin/*")
      @git.config.stub!(:[]).with("branch.master.remote").and_return('origin')
      @git.config.stub!(:[]).with("branch.master.merge").and_return("refs/heads/master")
      Git.command_response["remote"] = %Q{origin}
    
      # query the config - if source != self["remote.#{current_branch}.remote"] || self["remote.#{current_branch}.merge"].nil?
    
      # Git.command_response[] 
      Git.command_response["log", "-p", "791a587..4bfc230", "."] = fixture_file("log_with_diffs.txt")
      Git.command_response["log", "-p", "dc29d3d..05f9ad9", "."] = fixture_file("log_with_diffs.txt")
      Git.command_response["pull", "origin"] = fixture_file("pull_1_5_4_3_output.txt")
      
      @output = capture_output do
        dispatch :controller => "remote", :action => "pull"
      end
    end
    
    it "should output log of changes pulled" do
      @output.should include("Log of changes pulled")
      @output.should include("Branch 'master': 791a587..4bfc230")
      @output.should include("Branch 'asdf': dc29d3d..05f9ad9")
    end
  end
  
  describe "pushing" do
    before(:each) do
      Git.command_response["push", "origin", "master"] = (fixture_file("push_1_5_4_3_output.txt"))
      Git.command_response["branch"] = "* master\n  task"
      Git.command_response["log", ".", "865f920..f9ca10d"] = fixture_file("log.txt")
    end
    
    describe "to a server with one origin" do
      before(:each) do
        Git.command_response["remote"] = %Q{origin}
        @output = capture_output do
          dispatch :controller => "remote", :action => "push"
        end
      end
      
      it "should run all git commands" do
        Git.commands_ran.should == [["branch"], ["remote"], ["push", "origin", "master"], ["log", "865f920..f9ca10d", "."], ["branch"], ["branch"]]
      end
      
      it "should output log with diffs" do
        # puts (@output)
        @output.should include("Branch 'asdf': 865f920..f9ca10d")
      end
      
      it "should render the script on the top" do
        (Hpricot(@output) / "head / script").length.should >= 2
      end
    end
  end
  
  describe "pushing a tag" do
    before(:each) do
      @git = Git.singleton_new
      @git.should_receive(:sources).and_return(["origin"])
      @controller = RemoteController.singleton_new
      def @controller.for_each_selected_remote(options = {}, &block)
        yield "origin"
      end
    end
    
    it "should call run_push and then display_push_output" do
      @controller.should_receive(:run_push).with("origin", :tag => "mytag")
      @controller.should_receive(:display_push_output)
      @output = capture_output do
        dispatch(:controller => "remote", :action => "push_tag", :tag => "mytag")
      end
    end
  end
end