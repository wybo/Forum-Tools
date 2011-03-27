#!/usr/bin/ruby
$: << File.expand_path(File.dirname(__FILE__) + "/lib")
require 'rubygems'
require 'active_support/all'
require 'fileutils'
require 'h_n_tools'

HNTools.config(:start_time => Time.utc(2011,"jan",31))
HNTools.config(:from_dir => "/home/wybo/projects/hnscraper/production/")
HNTools.config(:root_dir => "/home/wybo/projects/hnscraper/test/")

def sample(options = {})
  start_time = HNTools::CONFIG[:start_time]
  if options[:time_offset]
    start_time += options[:time_offset]
  end
  if options[:time_span]
    end_time = start_time + options[:time_span]
  end
  puts "# Selecting files"
  list = []
  file_names = Dir.glob(HNTools::CONFIG[:from_dir] + HNTools::CONFIG[:data_dir] + "*")
  puts "globbed #{file_names.size.to_s} files"
  file_names.each do |file_name|
    if options[:time_span]
      if File.new(file_name).mtime > start_time and
          File.new(file_name).mtime < end_time
        list << File.basename(file_name)
      end
    end
  end
  puts "selected #{list.size.to_s}"
  return list
end

def populate(list)
  FileUtils.rm_rf(HNTools::CONFIG[:root_dir])
  HNTools.init_dirs()

  puts "# Copying files"
  list.each do |file_name|
    print "."
    FileUtils.copy(
        HNTools::CONFIG[:from_dir] + HNTools::CONFIG[:data_dir] + file_name,
        HNTools::CONFIG[:root_dir] + HNTools::CONFIG[:data_dir] + file_name) 
  end
  print "\n"
end

#list = sample(:time_span => 2.hours, :time_offset => 2.days)
list = sample(:time_span => 4.days)
populate(list)
