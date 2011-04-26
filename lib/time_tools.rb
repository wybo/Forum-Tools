require 'rubygems'
require 'tzinfo'
require 'active_support/all'

class TimeTools
  CONFIG = {} 
  CONFIG[:data_start_time] = Time.gm(2011, "feb", 1)

  WINDOWS = []
  WINDOWS << [23, 0, 1]
  (0..21).each do |i|
    WINDOWS << [i, i + 1, i + 2]
  end
  WINDOWS << [22, 23, 0]

  HALF_DAY = 12.hours.to_i

  PAJEK_COLORS = ["GreenYellow", "Yellow", "YellowOrange", "Orange", "RedOrange", "Red",
      "OrangeRed", "Magenta", "Lavender", "Thistle", "Purple", "Violet",
      "Blue", "NavyBlue", "CadetBlue", "MidnightBlue", "Cyan", "Turquose",
      "BlueGreen", "Emerald", "SeaGreen", "Green", "PineGreen", "YellowGreen"]
  PAJEK_NO_SINGLE_PEAK = "Grey"
  PAJEK_COLORS << PAJEK_NO_SINGLE_PEAK

  WHEEL_PART_PART = []
  4.times do |i|
    WHEEL_PART_PART << (255 / 4.0).ceil * i
  end
  8.times do
    WHEEL_PART_PART << 255
  end
  4.times do |i|
    WHEEL_PART_PART << 255 - (255 / 4.0).ceil * i
  end
  8.times do
    WHEEL_PART_PART << 0
  end
  WHEEL_PART = WHEEL_PART_PART.concat(WHEEL_PART_PART)
  WHEEL_COLORS = []
  24.times do |i|
    WHEEL_COLORS << [WHEEL_PART[i + 8], WHEEL_PART[i], WHEEL_PART[i - 8]]
  end
  WHEEL_NO_SINGLE_PEAK = [128, 128, 128]
  WHEEL_COLORS << WHEEL_NO_SINGLE_PEAK

  def self.in_time_window(window, time)
    hour = TimeTools.hour(time)
    if hour == WINDOWS[window][0] or hour == WINDOWS[window][1] or hour == WINDOWS[window][2]
      return true
    else
      return false
    end
  end

  def self.windows(time)
    hour = TimeTools.hour(time)
    return WINDOWS[hour] # real in middle 1 => [0,1,2]
  end

  def self.peak_window(times)
    window_counts = self.per_period_adder(times, "windows")
    max = window_counts.max # max window count
    # now collect all consecutive sets that have this count as well
    i = 0
    prev_count = 0
    collector = []
    collector_pointer = -1
    window_counts.each do |count|
      if count == max
        if prev_count != max
          collector_pointer += 1
          collector[collector_pointer] = []
        end
        collector[collector_pointer] << i
      end
      prev_count = count
      i += 1
    end
    # curl it around (23 - 0), 23 will always be longer
    if collector[0][0] == 0 and collector[-1][-1] == 23
      collector[-1].concat(collector[0])
    end
    # see which is longest
    max_sized_set = collector.max {|a,b| a.size <=> b.size}
    max_size = max_sized_set.size
    max_sizes = []
    i = 0
    collector.each do |subset|
      if subset.size == max_size
        max_sizes << i
      end
      i += 1
    end
    # if more than one take a random pick
    collected_set = collector[max_sizes.choice]
    # and return the middle-most window 
    # size 2 -> first, size 3 -> middle
    peak_window = collected_set[(collected_set.size - 1) / 2]
    return peak_window
  end

  def self.wheel_color_window(window)
    return WHEEL_COLORS[window]
  end

  def self.pajek_color_window(window)
    return ["ic", PAJEK_COLORS[window], "bc", PAJEK_COLORS[window]]
  end

  def self.per_period_adder(times, period_string)
    x_for_each_y = []
    if period_string == "hour" or period_string == "windows" or period_string == "echo_hour" # needed for hour alignments
      24.times do |i|
        x_for_each_y[i] = 0
      end
    end
    times.each do |time|
      periods = TimeTools.send(period_string, time)
      if !periods.kind_of?(Array)
        periods = [periods]
      end
      periods.each do |period|
        if !x_for_each_y[period]
          x_for_each_y[period] = 0
        end
        x_for_each_y[period] += 1
      end
    end
    return x_for_each_y
  end

  def self.single_peak(peak_window, posts_per_hour)
    posts_per_hour = posts_per_hour.dup
    peak_posts = 0
    WINDOWS[peak_window].each do |window_hour|
      peak_posts += posts_per_hour[window_hour]
    end
    overall_posts = 0
    posts_per_hour.each do |posts|
      overall_posts += posts
    end
    if peak_posts * 4 > overall_posts
      return true
    else
      return false
    end
  end

  def self.timezone_align_window(window, timezone_string, post_time)
    offset = TZInfo::Timezone.get(timezone_string).period_for_utc(post_time).utc_total_offset / 3600
    window = window + offset
    if window < 0
      window += 24
    end
    return window
  end

  def self.hour(time)
    return Time.at(time).utc.hour
  end

  def self.second_of_day(time)
    time_obj = Time.at(time).utc
    return time - Time.utc(time_obj.year, time_obj.month, time_obj.day).to_i
  end

  def self.day(time)
    return Time.at(time).utc.yday - TimeTools::CONFIG[:data_start_time].yday
  end

  def self.circadian_difference(difference)
    difference = difference.abs.to_i
    if difference > HALF_DAY
      return difference - (difference - HALF_DAY) * 2
    else
      return difference
    end
  end
end
