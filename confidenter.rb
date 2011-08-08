#!/usr/bin/ruby
require 'config'
require 'forum_tools'

puts "###### Confidence interval calculator"

initialize_environment(ARGV)

file_names = Dir.glob('../agent-based-forum/trunk/data/json/experiment*')

def confident_all(file_names)
  file_names.each do |file_name|
    collected_stat_data = {}
    collected_daily_stat_data = {}
    collected_critical_mass_data = {}
    new_file_name = file_name.split("/")[-1].gsub(".json", "")
    new_note = nil
    e = 0
    string = open(file_name).read
#    string = string[20..-5]
    experiment_strings = string.split("}}],[{")
    string = nil
    experiment_strings.each do |experiment_string|
      puts "Splitting experiment #{e}"
      if e == 0
        experiment_string = experiment_string[3..-1]
      end
      if e == experiment_strings.size - 1
        experiment_string = experiment_string[0..-5]
      end
      experiment = JSON.parse("[{" + experiment_string + "}}]")
      experiment_string = nil
      puts "Experiment #{e}"
      add_confident_experiment(experiment, collected_stat_data, collected_daily_stat_data,
        collected_critical_mass_data)
      experiment = nil
      stat_data = {}
      e += 1
    end

    puts "Saving to test stats"
    stat_file = "z_" + new_file_name + "."
    ForumTools::File.save_stat(stat_file + "critical." + new_note,
        collected_critical_mass_data)
    ForumTools::File.save_stat(stat_file + "daily." + new_note,
        collected_daily_stat_data, :add_case_numbers => true)
    ForumTools::File.save_stat(stat_file + new_note,
        collected_stat_data, :add_case_numbers => true)
  end
end

def add_confident_experiment(experiment, collected_stat_data, collected_daily_stat_data,
    collected_critical_mass_data)
#  experiment = [
#    {"config" => experiment["config"],
#     "data" => {"critical_mass_days_all" => experiment["data"]["critical_mass_days_all"]}}]

  experiment_data = read_experiment(experiment)
  stat_data = get_confidence_intervals(experiment_data)
      
  config = experiment[0]["config"]
  if !new_note
    new_note = config["note"].gsub(/[^\w]/,"-")
  end
  key_pre = "m" + config["mode"].to_s
  if config["initial_actors"] > 0
    key_pre += "i" + config["initial_actors"].to_s
  else
    key_pre += "a" + config["daily_arrivals"].to_s
  end

  cyclic_size = stat_data["posts"].size
  stat_data.keys.each do |key|
    if key =~ /critical_mass/
      collected_critical_mass_data[key_pre + key] = stat_data.delete(key)
    elsif stat_data[key].size != cyclic_size
      collected_daily_stat_data[key_pre + key] = stat_data.delete(key)
    else
      collected_stat_data[key_pre + key] = stat_data.delete(key)
    end
  end
end

def read_experiment(experiment)
  experiment_data = {}
  experiment.each do |rerun|
    rerun["data"].keys.each do |key|
      set = rerun["data"][key]
      v = 0
      if key == "critical_mass_days_all"
        experiment_data["critical_mass_days_all"] = [[]]
        set.each do |cell|
          if cell > 0
            experiment_data["critical_mass_days_all"][0] << cell
          end
        end
      elsif set.kind_of?(Array)
        set.each do |variable|
          if set.size > 1
            new_key = key.to_s + v.to_s
          else
            new_key = key
          end
          if !experiment_data[new_key]
            experiment_data[new_key] = []
          end
          c = 0
          variable.each do |cell|
            if !experiment_data[new_key][c]
              experiment_data[new_key][c] = []
            end
            experiment_data[new_key][c] << cell[1]
            c += 1
          end
          v += 1
        end
      elsif key == "critical_mass_days"
        if !experiment_data["critical_mass_days"]
          experiment_data["critical_mass_days"] = [[]]
        end
        if set >= 0
          experiment_data["critical_mass_days"][0] << set
        end
      end
    end
  end
  return experiment_data
end

def get_confidence_intervals(experiment_data)
  stat_data = {}
  experiment_data.keys.each do |key|
    lower_key = key.to_s + "_lower"
    upper_key = key.to_s + "_upper"
    experiment_data[key].each do |sample|
      if !stat_data[key]
        stat_data[lower_key] = []
        stat_data[key] = []
        stat_data[upper_key] = []
      end
      interval = confidence_interval(sample)
      stat_data[lower_key] << round_2(interval[:lower])
      stat_data[key] << round_2(interval[:mean])
      stat_data[upper_key] << round_2(interval[:upper])
    end
  end
  return stat_data
end

def variance_and_stats(sample)
  n = 0.0
  mean = 0.0
  s = 0.0
  sample.each { |x|
    if x != nil
      n += 1
      delta = x - mean
      mean = mean + (delta / n)
      s = s + delta * (x - mean)
    end
  }
  if n != 1
    return {:variance => s / (n - 1), :mean => mean, :n => n}
  else
    return {:variance => 0, :mean => mean, :n => n}
  end
end

def stats(sample)
  stats = variance_and_stats(sample)
  if stats[:variance] >= 0
    stats[:standard_deviation] = Math.sqrt(stats[:variance])
  else
    stats[:standard_deviation] = Math.sqrt(stats[:variance] * -1) * -1
  end
  if stats[:n] > 0
    stats[:means_standard_deviation] = stats[:standard_deviation] / Math.sqrt(stats[:n])
  else
    stats[:means_standard_deviation] = 0
  end
  return stats
end

def confidence_interval(sample)
  stats = stats(sample)
  difference = 1.96 * stats[:means_standard_deviation]
  return {
      :lower => stats[:mean] - difference,
      :mean => stats[:mean],
      :upper => stats[:mean] + difference
    }
end

def round_2(number)
  return (number * 100.0).round / 100.0
end

confident_all(file_names)
