class DiffController < ApplicationController
  
  def diff
    show_diff_title unless params[:layout].to_s=="false"
    @rev = params[:rev]
    @title = params[:title] || "Uncomitted changes"
    render("_diff_results", :locals => {:diff_results => git.diff(params)})
  end
  
  def uncommitted_changes
    paths = case
      when params[:path] 
        [params[:path]]
      else
        git.paths(:fallback => :current_file, :unique => true)
      end
    base = git.nca(paths)
    @title = "Uncomitted Changes for ‘#{htmlize(paths.map{|path| shorten(path, base)} * ', ')}’"
    open_in_tm_link
    
    paths.each do |path|
      render("_diff_results", :locals => {:diff_results => git.diff(:file => path, :since => "HEAD") })
    end
  end
  
  def compare_revisions
    filepaths = git.paths.first
    if filepaths.length > 1
      base = git.nca(filepaths)
    else 
      base = filepaths.first
    end
    
    log = LogController.new
    revisions = log.choose_revision(base, "Choose revisions for #{filepaths.map{|f| git.make_local_path(f)}.join(',')}", :multiple, :sort => true)

    if revisions.nil?
      puts "Canceled"
      return
    end
    
    render_component(:controller => "diff", :action => "diff", :revisions => revisions, :path => base)
  end
  
protected
  def open_in_tm_link
    puts <<-EOF
      <a href='txmt://open?url=file://#{e_url '/tmp/output.diff'}'>Open diff in TextMate</a>
    EOF
  end
  
  def show_diff_title
    puts "<h2>"
    case
    when params[:branches]
      branches = params[:branches]
      branches = branches.split("..") if params[:branches].is_a?(String)
      puts "Comparing branches #{branches.first}..#{branches.last}"
    when params[:revisions]
      revisions = params[:revisions]
      revisions = revisions.split("..") if params[:revisions].is_a?(String)
      puts "Comparing branches #{revisions.first}..#{revisions.last}"
    end
    puts "</h2>"
  end

end