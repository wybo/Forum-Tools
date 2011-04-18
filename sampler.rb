#!/usr/bin/ruby
require 'config'
require 'stores'
require 'active_support/all'

puts "### Taking a sample"

def sample(options = {})
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
    time = Time.at(ForumTools::File.parse_file_time(file_name))
    base_name = File.basename(file_name)
    if (time > start_time and time < end_time) or 
        (ForumTools::CONFIG[:environment] != "test" and base_name =~ /^user_/)
      list << base_name
    end
  end
  puts "selected #{list.size.to_s}"
  return list
end

def days_sample(options = {})
  puts "# Selecting files"
  list = []
  file_names = Dir.glob(ForumTools::CONFIG[:production_dir] +
      ForumTools::CONFIG[:yaml_dir] + "*")
  file_names.each do |file_name|
    base_name = File.basename(file_name)
    if base_name == "users.yaml"
      list << base_name
    else
      thread = ThreadStore.new(:file_name => base_name, 
          :env_dir => ForumTools::CONFIG[:production_dir])
      time = Time.at(thread[0][:time])
      if (options[:days].include?(time.wday))
        list << base_name
      end
    end
  end
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

args = ARGV.to_a
if args[0] == "midweek" # also env
  initialize_environment(args)
  list = days_sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:yaml_dir])
else
  initialize_environment(args)
  list = sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
  populate(list, ForumTools::CONFIG[:raw_dir])
end
