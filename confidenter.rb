#!/usr/bin/ruby
require 'config'
require 'forum_tools'

puts "###### Confidence interval calculator"

initialize_environment(ARGV)

file_names = Dir.glob('../agent-based-forum/trunk/data/json/experiment*')

file_names = ["../agent-based-forum/trunk/data/json/experiment.1311447101.json"]

def confident_all(file_names)
  file_names.each do |file_name|
    contents = JSON.parse(open(file_name).read)
    new_file_name = file_name.split("/")[-1].gsub(".json", "")
    new_note = nil
    e = 0
    contents.each do |experiment|
      puts "Experiment " + e.to_s
      config = experiment[0]["config"]
      if !new_note
        new_note = config["note"].gsub(/[^\w]/,"-")
      end

      experiment_data = read_experiment(experiment)
      stat_data = get_confidence_intervals(experiment_data)
      e += 1
      
      ForumTools::File.save_stat("z_" + new_file_name + "_initial." + config["initial_actors"].to_s + "_" + new_note,
          stat_data)
    end
  end
end

def read_experiment(experiment)
  experiment_data = {}
  experiment.each do |rerun|
    rerun[:data].keys.each do |key|
      set = rerun[:data][key]
      v = 0
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
      stat_data[lower_key] << interval[:lower]
      stat_data[key] << interval[:mean]
      stat_data[upper_key] << interval[:upper]
    end
  end
  return stat_data
end

def variance_and_stats(sample)
  n = 0.0
  mean = 0.0
  s = 0.0
  sample.each { |x|
    puts sample.inspect if x == nil
    n += 1
    delta = x - mean
    mean = mean + (delta / n)
    s = s + delta * (x - mean)
  }
  return {:variance => s / (n - 1), :mean => mean, :n => n}
end

def stats(sample)
  stats = variance_and_stats(sample)
  stats[:standard_deviation] = Math.sqrt(stats[:variance])
  stats[:means_standard_deviation] = stats[:standard_deviation] / Math.sqrt(stats[:n])
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

def symbolize_keys(hash_or_array)
  if hash_or_array.kind_of?(Hash)
    return symbolize_keys_hash(hash_or_array)
  elsif hash_or_array.kind_of?(Array)
    return symbolize_keys_array(hash_or_array)
  else
    return hash_or_array
  end
end

def symbolize_keys_array(array)
  return array.inject([]) { |new_array, value|
    if !value.kind_of?(String)
      value = symbolize_keys(value)
    end
    new_array << value
    new_array
  }
end

def symbolize_keys_hash(hash)
  return hash.inject({}) { |new_hash, key_value|
    key, value = key_value
    if !value.kind_of?(String)
      value = symbolize_keys(value)
    end
    new_hash[key.to_sym] = value
    new_hash
  }
end

confident_all(file_names)
