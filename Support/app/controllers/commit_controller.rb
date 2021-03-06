CW = ENV['TM_SUPPORT_PATH'] + '/bin/CommitWindow.app/Contents/MacOS/CommitWindow'

class CommitController < ApplicationController
  def index
    if git.merge_message
      @status = git.status
      @message = git.merge_message 
      render "merge_commit"
    else
      run_partial_commit
    end
  end
  
  def merge_commit
    message = params[:message]
    statuses = git.status(git.git_base)
    files = statuses.map { |status_options| (status_options[:status][:short] == "G") ? git.make_local_path(status_options[:path]) : nil }.compact

    auto_add_rm(files)
    res = git.commit(message, [])
    
    render "_commit_result", :locals => { :result => res, :files => files, :message => message }
  end
  
  protected
    
    def ok_to_proceed_with_partial_commit?
      (! git.branch.current_name.nil?) || git.initial_commit_pending?
    end
    
    def run_partial_commit
      @base = git.git_base
      
      unless ok_to_proceed_with_partial_commit?
        render "not_on_a_branch"
        return false
      end
      
      target_file_or_dir = git.paths.first
      puts "<h1>Committing Files in ‘#{htmlize(shorten(target_file_or_dir, ENV['TM_PROJECT_DIRECTORY'] || @base))}’ on branch ‘#{htmlize(git.branch.current_name)}’</h1>"
      flush

      files, statuses = [], []
      git.status(target_file_or_dir).each do |e|
        files  << e_sh(shorten(e[:path], @base))
        statuses << e_sh(e[:status][:short])
      end
      
      if files.empty?
        puts (git.clean_directory? ? "Working directory is clean (nothing to commit)" : "No changes to commit within the current scope. (Try selecting the root folder in the project drawer?)")
        return
      end
      
      msg, files = show_commit_dialog(files, statuses)

      unless files.empty?
        auto_add_rm(files)
        res = git.commit(msg, files)
        render "_commit_result", :locals => { :files => files, :message => msg, :result => res}
      end
    end
    
    def show_commit_dialog(files, statuses)
      status_helper_tool = ENV['TM_BUNDLE_SUPPORT'] + '/gateway/commit_dialog_helper.rb'
      
      res = %x{#{e_sh CW}                 \
        --diff-cmd   '#{git.git},diff'        \
        --action-cmd "M,D:Revert,#{status_helper_tool},revert" \
        --status #{statuses.join ':'}       \
        #{files.join ' '} 2>/dev/console
      }

      if $? != 0
        puts "<strong>Cancel</strong>"
        abort
      end

      res   = Shellwords.shellwords(res)
      msg = res[1]
      files = res[2..-1]
      return msg, files
    end
    
    def auto_add_rm(files)
      git.chdir_base
      add_files = files.select{ |f| File.exists?(f) }
      remove_files = files.reject{ |f| File.exists?(f) }
      res = git.add(add_files) unless add_files.empty?
      res = git.rm(remove_files) unless remove_files.empty?
    end
end