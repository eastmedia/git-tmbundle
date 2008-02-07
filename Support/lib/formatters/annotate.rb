class Formatters::Annotate
  include Formatters::FormatterHelpers
  
  def initialize(options = {}, &block)
    @base = options[:base] || ENV["TM_PROJECT_DIRECTORY"]
    @header = options[:header] || "Annotate / Blame"
    @log_entries = options[:log_entries]
    @selected_revision = options[:selected_revision]
    @as_partial = options[:as_partial]
    
    layout {yield self} if block_given?
  end
  
  def layout(&block)
    puts <<-EOF
    <html>
    <head>
      <title>#{@header}</title>
      <link type="text/css" rel="stylesheet" media="screen" href="#{resource_url('style.css')}"/>
    </head>
    <body id='body'>
    EOF
    yield
    
    puts <<-EOF
    </body>
    <script type='text/javascript' src="#{resource_url('prototype.js')}"></script>
    <script type='text/javascript' src="#{resource_url('rb_gateway.js')}"></script>
    <script language='JavaScript'>
      function show_revision(revision)
      {
        $('content').update(gateway_command('annotate.rb', [revision]));
      }
      
      function keypress_listener(e) 
      {
        // if (e.keyCode==Event.KEY_LEFT)
        //   $('debug').update('escape!!!');
        // else
        //   $('debug').update(e.keyCode)
          
        switch(e.keyCode) {
          case 110: // n
            if ($('rev').selectedIndex >= 1)
            {
              $('rev').selectedIndex = $('rev').selectedIndex - 1
              $('rev').onchange();
            }
              
            break;
          case 112: // p
            if ($('rev').selectedIndex < $('rev').options.length - 1)
            {
              $('rev').selectedIndex = $('rev').selectedIndex + 1
              $('rev').onchange();
            }
            break;
          case 78: // P
            $('rev').selectedIndex = 0;
            $('rev').onchange();
            break;
          case 80: // N
            $('rev').selectedIndex = $('rev').options.length - 1;
            $('rev').onchange();
            break;
        }
        // $('debug').update(e.keyCode);
      }
      
      try {
        Event.observe(document, "keypress", keypress_listener.bindAsEventListener());
      }
      catch (e) {
        $('debug').update(e)
      }
      
    </script>
    </html>
    EOF
  end
  
  def header(text)
    @header = text
    # puts "<h2>#{text}</h2>"
  end
  
  def make_non_breaking(output)
    htmlize(output.to_s.strip).gsub(" ", "&nbsp;")
  end
  
  def options_for_select(select_options = [], selected_value = nil)
    output = ""
    
    select_options.each do |name, val|
      selected = (val == selected_value) ? "selected='true'" : ""
      output << "<option value='#{val}' #{selected}>#{htmlize(name)}</option>"
    end
    
    output
  end
  
  def select_box(name, select_options = [], options = {})
    options[:name] ||= name
    options[:id] ||= name
    # puts select_options.inspect
    <<-EOF
      <select name='#{options[:name]}' id='#{options[:id]}' onchange="#{options[:onchange]}" style='width:100%'>
        #{select_options}
      </select>
    EOF
  end
  
  def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round
    
    case distance_in_minutes
      when 0..1
        return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute' unless include_seconds
        case distance_in_seconds
          when 0..4   then 'less than 5 seconds'
          when 5..9   then 'less than 10 seconds'
          when 10..19 then 'less than 20 seconds'
          when 20..39 then 'half a minute'
          when 40..59 then 'less than a minute'
          else             '1 minute'
        end
      
      when 2..44           then "#{distance_in_minutes} minutes"
      when 45..89          then 'about 1 hour'
      when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
      when 1440..2879      then '1 day'
      when 2880..43199     then "#{(distance_in_minutes / 1440).round} days"
      when 43200..86399    then 'about 1 month'
      when 86400..525599   then "#{(distance_in_minutes / 43200).round} months"
      when 525600..1051199 then 'about 1 year'
      else                      "over #{(distance_in_minutes / 525600).round} years"
    end
  end
  
  def relative_date(date)
    return date if date.is_a?(String)
    distance_of_time_in_words(Time.now, date)
  end
  
  def htmlize_attr(str)
    str.to_s.gsub(/"/, "&quot;").gsub("<", "&lt;").gsub(">", "&gt;")
  end
  
  def navigate_box
    formatted_options = [["current", ""]] + @log_entries.map{|le| ["#{short_rev(le[:rev])} - #{relative_date(le[:date])} - #{le[:author]} - #{le[:msg].split("\n").first}", short_rev(le[:rev])] }
    select_box_html = select_box(
      "rev",
      options_for_select(formatted_options, @selected_revision),
      :onchange => "show_revision($F(this))"
    )
    
    puts <<-EOF
      <div style='position:fixed; top:0px; background: #fff; width: 100%;'>
        <div id='debug'></div>
        <div style='float:right'>
          <b>Keys</b>: n - <em>next revision</em>, p - <em>previous revision</em>, N - <em>current</em>, P - <em>earliest revision</em>
        </div>
        #{@header}
        <br clear='both'/>
        #{select_box_html}
      </div>
    EOF
    
    puts 
  end
  
  def content(annotations)
    # puts annotations.inspect
    puts '<code>'
    
    puts "<div id='content' style='margin-top:60px;'>" unless @as_partial
    
    puts <<-EOF
      <table class='codediff inline'>
        <thead>
          <tr>
            <td class='line-numbers'>revision</td>
            <td class='line-numbers'>author</td>
            <td class='line-numbers'>date</td>
            <td class='line-numbers'>line</td>
            <td/>
          </tr>
        </thead>
        <tbody>
    EOF
    last_formatted_line = {}
    
    annotations.each do |annotation|
      col_class = []
      col_class << "selected" if ENV["TM_LINE_NUMBER"].to_i == annotation[:ln].to_i
      col_class << "ins" if annotation[:rev] == "-current-" || annotation[:rev] == @selected_revision
      col_class = col_class * " "
      formatted_line = {
        :rev => annotation[:rev], 
        :author => annotation[:author], 
        :date => relative_date(annotation[:date]), 
        :ln => annotation[:ln], 
        :text => annotation[:text]
      }
      display = formatted_line.dup
      
      [:rev, :author, :date].each { |k| display[k] = "…" } if display[:rev]==last_formatted_line[:rev]
      
      friendly_date = annotation[:date].is_a?(Time) ? annotation[:date].to_friendly : annotation[:date]
      
      rev_hover_message = <<EOF
Revision: #{annotation[:rev]}
Date: #{friendly_date} (#{display[:date]})
Author: #{annotation[:author]}
EOF
      
      date_line = make_non_breaking(display[:date])
      date_line = %Q{<abbr title="#{annotation[:date].to_friendly}\nasdf">#{date_line}</abbr>} unless display[:date]=="…" if annotation[:date].is_a?(Time)
      rev_line = make_non_breaking display[:rev]
      rev_line = %Q{<a title="#{htmlize_attr(rev_hover_message)}" href='javascript:show_revision("#{annotation[:rev]}"); return false;'>#{rev_line}</a>} unless display[:rev]=="…"
      puts <<-EOF
        <tr>
          <td class="line-numbers">#{rev_line}</td>
          <td class="line-numbers">#{make_non_breaking display[:author]}</td>
          <td class="line-numbers">#{date_line}</td>
          <td class="line-numbers">#{display[:ln]}</td>
          <td class="code #{col_class}">#{htmlize(display[:text])}</td>
        </tr>
      EOF
      last_formatted_line = formatted_line
    end
      
    puts <<-EOF
        </tbody>
      </table>
    EOF
    
    puts "</div><!-- end div#content -->" unless @as_partial
    puts js_select_current_revision
    puts '</code>'
  end
  
  def js_select_current_revision
    <<-EOF
    <script language="JavaScript">
      selected_map = $A($('rev').options).map(function(o) { return o.value == '#{@selected_revision}'});
      // $('debug').update(selected_map.join(", "));
      $('rev').selectedIndex = selected_map.indexOf(true);
    </script>
    EOF
  end

end


module FriendlyTime
  def to_friendly(time=true)
    time=false if Date==self.class
    
    ret_val = if time
      strftime "%b %d, %Y %I:%M %p" + (time=="zone"? " %Z" : "")
    else
      strftime "%b %d, %Y"
    end
    
    ret_val.gsub(" 0", " ")
  end
end

class Time
  include FriendlyTime
end

class Date
  include FriendlyTime
end

class DateTime
  include FriendlyTime
end

