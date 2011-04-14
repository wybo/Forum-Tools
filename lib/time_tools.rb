require 'rubygems'
require 'active_support/all'

class TimeTools
  CONFIG = {} 
  CONFIG[:data_start_time] = Time.gm(2011, "feb", 1)

  WINDOWS = []
  (0..21).each do |i|
    WINDOWS << [i, i + 1, i + 2]
  end
  WINDOWS << [22, 23, 0]
  WINDOWS << [23, 0, 1]

  HALF_DAY = 12.hours.to_i

  def self.in_time_window(window, time)
    hour = TimeTools.hour(time)
    if hour == WINDOWS[window][0] or hour == WINDOWS[window][1] or hour == WINDOWS[window][2]
      return true
    else
      return false
    end
  end

  def self.window(time)
    hour = TimeTools.hour(time)
    return WINDOWS[hour - 2] # as windows translate back 3 - 2 = 1 => [1,2,3]
  end

  def self.per_period_adder(times, period_string)
    x_for_each_y = []
    if period_string == "hour" or period_string == "window" # needed for hour alignments
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
    if peak_posts * 2 > overall_posts
      return true
    else
      return false
    end
  end

  def self.hour(time)
    return Time.at(time).hour
  end

  def self.second_of_day(time)
    time = Time.at(time)
    return time - Time.utc(time.year, time.month, time.day).to_i
  end

  def self.day(time)
    return Time.at(time).yday - TimeTools::CONFIG[:data_start_time].yday
  end

  def self.circadian_difference(difference)
    difference = difference.abs
    if difference > HALF_DAY
      return difference - (difference - HALF_DAY) * 2
    else
      return difference
    end
  end
end
