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
  file_names = Dir.glob(ForumTools::CONFIG[:production_dir] +
      ForumTools::CONFIG[:yaml_dir] + "*")
  file_names.each do |file_name|
    base_name = File.basename(file_name)
    if base_name !~ /^user/
      thread = ThreadStore.new(:file_name => base_name, 
          :env_dir => ForumTools::CONFIG[:production_dir])
      time = Time.at(thread[0][:time]).utc
      if (!options[:days] or options[:days].include?(time.wday) and 
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

def populate(list, raw_yaml)
  ForumTools::File.clear_dirs()
  ForumTools::File.init_dirs()

  puts "# Copying files"
  list.each do |file_name|
    print "."
    FileUtils.copy(
        ForumTools::CONFIG[:production_dir] + raw_yaml + file_name,
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

args = ARGV.to_a
if args[0] == "after"
  args.delete_at(0)
  initialize_environment(args)
  list = after_parse_sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:yaml_dir])
  link_raw()
else
  initialize_environment(args)
  list = sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:raw_dir])
end
