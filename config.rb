$: << File.expand_path(File.dirname(__FILE__) + "/lib")
$stdout.sync = true # For progress dots
require 'forum_tools'

def initialize_environment(args)
  # Time the sample starts
  ForumTools.config(:data_start_time => Time.utc(2011,"jan",31))

  # Environment set as argument
  if args[0].nil?
    ForumTools.config(:environment => "test")
  else
    ForumTools.config(:environment => args[0])
  end

  # Sampling time-ranges for environments
  ForumTools.config(:samples => {
      :test => {:time_offset => 2.days, :time_span => 26.hours},
      :febmar => {:end_time => Time.utc(2011,"apr",1)}
  })

  # Overall root
  ForumTools.config(:root_dir => "/home/wybo/projects/hnscraper/")

  # The root dir normally used in the scripts
  ForumTools.config(:env_dir => ForumTools::CONFIG[:root_dir] + ForumTools::CONFIG[:environment] + "/")

  # Production data dir, used by sampler as source dir
  ForumTools.config(:production_dir => ForumTools::CONFIG[:root_dir] + "production/")

  # Var
  ForumTools.config(:data_dir => "data/")
  ForumTools.config(:var_dir => "var/")

  # Sub-dirs for data
  ForumTools.config(:raw_dir => ForumTools::CONFIG[:data_dir] + "raw/")
  ForumTools.config(:yaml_dir => ForumTools::CONFIG[:data_dir] + "yaml/")
  ForumTools.config(:pajek_dir => ForumTools::CONFIG[:data_dir] + "pajek/")
  ForumTools.config(:stat_dir => ForumTools::CONFIG[:data_dir] + "stat/")

  # Make sure directories are created
  ForumTools::File.init_dirs()
end
