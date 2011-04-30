#!/usr/bin/ruby
require 'config'
require 'time_tools'

puts '### Adding arrows to SVG\'s'

def do_arrows(options = {})
  file_names = get_all_files()
  file_names.each do |file_name|
    base_name = File.basename(file_name)
    puts "Processing " + base_name
    contents = read_file(file_name)
    new_contents = []
    found_path = false
    line_color = nil
    done = true
    contents.each do |line|
      if line == '    </g>'
        done = true
      end
      if line == '    <g id="edges">'
        done = false
        new_contents << <<-EOS
    <defs
      id="defs4856">
EOS
        path = 7777
        i = 0
        TimeTools::WHEEL_COLORS.each do |colors| 
          color = "%02x%02x%02x" % colors
          new_contents << <<-EOS
      <marker
        orient="auto"
        refY="0.0"
        refX="0.0"
        id="Arrow1Mend#{color}"
        style="overflow:visible;">
        <path
           id="path#{path}"
           d="M 0.0,0.0 L 5.0,-5.0 L -12.5,0.0 L 5.0,5.0 L 0.0,0.0 z "
           style="fill:##{color};stroke:##{color};stroke-width:1.0pt;marker-start:none;"
           transform="scale(0.4) rotate(180) translate(10,0)" />
      </marker>
EOS
          path += 1
          i += 1
        end
        new_contents << <<-EOS
    </defs>
EOS
      end
      if !done
        if line =~ /        <path/
          line_color = nil
        end
        if line.strip =~ /stroke=/
          line =~ /stroke="#([^"]+)"/
          line_color = $1
        end
        if line_color
          new_contents << <<-EOS
              marker-end="url(#Arrow1Mend#{line_color})"
EOS
        end
      end
      new_contents << line
    end
    save_file(file_name, new_contents)
  end
end

def get_all_files
  list = Dir.glob(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:net_dir] + "*.svg")
  list.reject! {|file_name| 
    base_name = File.basename(file_name) 
    base_name =~ /arrowed.svg$/ or base_name =~ /^all_replies.cut_false/
  }
  return list.sort
end

def read_file(dir_file_name, options = {})
  if File.exists?(dir_file_name)
    contents = File.open(dir_file_name).readlines
  end
  new_contents = []
  contents.each do |line|
    line.chomp!
    if line =~ /" stroke=/
      two_lines = line.split(" stroke=")
      new_contents << two_lines[0]
      line = "              stroke=" + two_lines[1]
    end
    new_contents << line
  end
  return new_contents
end

def save_file(dir_file_name, contents)
  contents = contents.join("\n").split("\n").reject {|line| line == ""}
  dir_file_name.gsub!(/.svg$/, ".arrowed.svg")
  File.open(dir_file_name, "w") { |file|
    file.write(contents.join("\n")) }
end

args = ARGV.to_a
initialize_environment(args)
options = {}

do_arrows(options)
