#!/usr/bin/ruby
require 'config'
require 'stores'
require 'active_support/all'

puts "### Taking a sample"

def sample(options = {})
  puts "# Selecting raw files"
  if options[:start_time]
    start_time = options[:start_time]
  else
    start_time = ForumTools::CONFIG[:data_start_time]
  end
  if ForumTools::CONFIG[:environment] == "test"
    end_time = options[:end_time]
  else
    end_time = options[:end_time] + 2.days # grace-period to collect time-stamps
  end
  puts "# Selecting files"
  list = []
  file_names = Dir.glob(ForumTools::CONFIG[:production_dir] +
      ForumTools::CONFIG[:raw_dir] + "*")
  file_names.each do |file_name|
    time = Time.at(ForumTools::File.parse_file_time(file_name)).utc
    base_name = File.basename(file_name)
    if (time > start_time and time < end_time) or 
        (ForumTools::CONFIG[:environment] != "test" and base_name =~ /^user_/)
      list << base_name
    end
  end
  puts "selected #{list.size.to_s}"
  return list
end

def after_parse_sample(options = {})
  puts "# Selecting yaml files"
  list = []
  file_names = Dir.glob(ForumTools::CONFIG[:febmar_dir] +
      ForumTools::CONFIG[:yaml_dir] + "*")
  file_names.each do |file_name|
    base_name = File.basename(file_name)
    if base_name !~ /^user/
      thread = ThreadStore.new(:file_name => base_name, 
          :env_dir => ForumTools::CONFIG[:production_dir])
      time = Time.at(thread[0][:time]).utc
      if (!options[:days] or options[:days].include?(time.wday) and 
          (!options[:start_time] or time > options[:start_time]) and
          (!options[:end_time] or time < options[:end_time]))
        list << base_name
      end
    end
    print "."
  end
  print "\n"
  puts "selected #{list.size.to_s}"
  return list
end

def after_parse_forum_sample(options = {}) # Only for boards format
  puts "# Selecting yaml files"
  list = []
  dir_names = Dir.glob(ForumTools::CONFIG[:boards_dir] +
      ForumTools::CONFIG[:yaml_dir] + "*")
  selected_dir_names = []
  options[:select].times do
    dir_name = dir_names.choice
    forum_name = File.basename(dir_name)
    file_names = Dir.glob(dir_name + "/*")
    file_names.each do |file_name|
      base_name = File.basename(file_name)
      if base_name !~ /^user/
        list << forum_name + "/" + base_name
      end
      print "."
    end
  end
  print "\n"
  puts "selected #{options[:select]} forums and #{list.size.to_s} threads"
  return list
end

def populate(list, source_dir, raw_yaml)
  ForumTools::File.clear_dirs()
  ForumTools::File.init_dirs()

  puts "# Copying files"
  list.each do |file_name|
    if file_name =~ /^\d+\//
      FileUtils.mkdir_p(ForumTools::CONFIG[:env_dir] + raw_yaml + File.basename(File.dirname(file_name)))
    end
    print "."
    FileUtils.copy(
        source_dir + raw_yaml + file_name,
        ForumTools::CONFIG[:env_dir] + raw_yaml + file_name)
  end
  print "\n"
end

def link_raw
  if ForumTools::CONFIG[:env_dir] != ForumTools::CONFIG[:production_dir]
    FileUtils.rm_rf(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir])
    `cd #{ForumTools::CONFIG[:env_dir]}; ln -s #{ForumTools::CONFIG[:febmar_dir] + ForumTools::CONFIG[:raw_dir]} #{ForumTools::CONFIG[:raw_dir].chop}`
  end
end

overall_options = {}
args = ARGV.to_a
if args[0] == "after"
  args.delete_at(0)
  overall_options[:sample] = :after
elsif args[0] == "forums"
  args.delete_at(0)
  overall_options[:sample] = :forums
end

initialize_environment(args)

if overall_options[:sample] == :after
  list = after_parse_sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:febmar_dir], ForumTools::CONFIG[:yaml_dir])
  link_raw()
elsif overall_options[:sample] == :forums
  list = after_parse_forum_sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:boards_dir], ForumTools::CONFIG[:yaml_dir])
else
  list = sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:production_dir], ForumTools::CONFIG[:raw_dir])
end

initialize_environment(args)
