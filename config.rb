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
      :test => {:start_time => Time.utc(2011,"feb",2), :end_time => Time.utc(2011,"feb",4)},
      :febmar => {:end_time => Time.utc(2011,"apr",2)},
      :midweek => {:days => [2,3]},
      :standard => {:days => [2,3], :end_time => Time.utc(2011,"mar",12)}
  })

  # Minimum number of posts required if in prolific category
  ForumTools.config(:prolific_cutoff => (ForumTools::CONFIG[:environment] == "test" ? 3 : 25))
  #ForumTools.config(:prolific_cutoff => (ForumTools::CONFIG[:environment] == "test" ? 3 : 60))
  ForumTools.config(:unprolific_cutdown => (ForumTools::CONFIG[:environment] == "test" ? 2 : 5))
  #ForumTools.config(:prolificity_prune => :unprolific)
  ForumTools.config(:prolificity_prune => false)
  ForumTools.config(:interaction_cutoff => (ForumTools::CONFIG[:environment] == "test" ? 2 : 1))
#  ForumTools.config(:reciprocity_cutoff => (ForumTools::CONFIG[:environment] == "test" ? 2 : 2))
  ForumTools.config(:max_hours_on_frontpage => 12)
  ForumTools.config(:only_single_peak => false)
  ForumTools.config(:undirected => true)
  ForumTools.config(:hop_cutoff => 5) # for regression

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
  ForumTools.config(:net_dir => ForumTools::CONFIG[:data_dir] + "net/")
  ForumTools.config(:stat_dir => ForumTools::CONFIG[:data_dir] + "stat/")

  # For yaml.js, importing into agent-based-forum
  ForumTools.config(:abf_dir => "/home/wybo/projects/agent-based-forum/trunk/")

  # Make sure directories are created
  ForumTools::File.init_dirs()
end
