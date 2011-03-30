#!/usr/bin/ruby
require 'config'
require 'active_support/all'

initialize_environment(ARGV)

def sample(options = {})
  puts options.inspect
  start_time = ForumTools::CONFIG[:data_start_time]
  if options[:time_offset]
    start_time += options[:time_offset]
  end
  if options[:time_span]
    end_time = start_time + options[:time_span]
  elsif options[:end_time]
    end_time = options[:end_time]
  end
  puts "# Selecting files"
  list = []
  file_names = Dir.glob(ForumTools::CONFIG[:production_dir] +
      ForumTools::CONFIG[:raw_dir] + "*")
  file_names.each do |file_name|
    if File.new(file_name).mtime > start_time and
        File.new(file_name).mtime < end_time
      list << File.basename(file_name)
    end
  end
  puts "selected #{list.size.to_s}"
  return list
end

def populate(list)
  if ForumTools::CONFIG[:env_dir] == ForumTools::CONFIG[:production_dir]
    raise "Cannot populate production dir as this would delete all files"
  end
  FileUtils.rm_rf(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:data_dir])
  ForumTools::File.init_dirs()

  puts "# Copying files"
  list.each do |file_name|
    print "."
    FileUtils.copy(
        ForumTools::CONFIG[:production_dir] + ForumTools::CONFIG[:raw_dir] + file_name,
        ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:raw_dir] + file_name) 
  end
  print "\n"
end

list = sample(ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym])
populate(list)
