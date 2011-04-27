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
      :febmarmw => {:days => [2,3]},
      :standard => {:end_time => Time.utc(2011,"mar",12)},
      :standardmw => {:days => [2,3], :end_time => Time.utc(2011,"mar",12)},
      :dst2weeksbefore => {:start_time => Time.utc(2011,"feb",28), :end_time => Time.utc(2011,"mar",11)},
      :dst2weeksafter => {:start_time => Time.utc(2011,"mar",14), :end_time => Time.utc(2011,"mar",25)}
  })

  ForumTools.config(:prolific_cutoff => (ForumTools::CONFIG[:environment] == "test" ? 3 : 25))
  ForumTools.config(:unprolific_cutdown => (ForumTools::CONFIG[:environment] == "test" ? 2 : 5))
  #ForumTools.config(:prolificity_prune => false)
  ForumTools.config(:max_hours_on_frontpage => 50)
  ForumTools.config(:only_single_peak => false)
  ForumTools.config(:between_replies_only => false)
  ForumTools.config(:undirected => false)

  network = :window

  if network == :test
    #ForumTools.config(:interaction_cutoff => 2)
    ForumTools.config(:reciprocity_cutoff => 2)
    #ForumTools.config(:prolificity_prune => :unprolific)
  elsif network == :window
    ForumTools.config(:undirected => false)
    ForumTools.config(:max_hours_on_frontpage => 50)
  elsif network == :whole
    ForumTools.config(:max_hours_on_frontpage => 50)
  elsif network == :unprolific
    ForumTools.config(:prolificity_prune => :unprolific)
  elsif network == :reciprocity
    ForumTools.config(:reciprocity_cutoff => 3)
#    ForumTools.config(:prolificity_prune => :unprolific)
  elsif network == :interaction
    ForumTools.config(:interaction_cutoff => 4)
  end

  # For regression
  ForumTools.config(:hop_cutoff => 20)

  # Overall root
  ForumTools.config(:root_dir => "/home/wybo/projects/hnscraper/")

  # The root dir normally used in the scripts
  ForumTools.config(:env_dir => ForumTools::CONFIG[:root_dir] + ForumTools::CONFIG[:environment] + "/")

  # Production data dir, used by sampler as source dir
  ForumTools.config(:production_dir => ForumTools::CONFIG[:root_dir] + "production/")
  ForumTools.config(:febmar_dir => ForumTools::CONFIG[:root_dir] + "febmar/")

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
