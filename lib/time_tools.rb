require 'rubygems'
require 'active_support/all'

class TimeTools
  CONFIG = {} 
  CONFIG[:data_start_time] = Time.gm(2011, "feb", 1)

  WINDOWS = []
  (0..22).each do |i|
    WINDOWS << [i, i + 1]
  end
  WINDOWS << [23, 0]

  def self.in_time_window(window, time)
    hour = TimeTools.hour(time)
    if hour == WINDOWS[window][0] or hour == WINDOWS[window][1]
      return true
    else
      return false
    end
  end

  def self.hour(time)
    return Time.at(time).hour
  end

  def self.day(time)
    return Time.at(time).yday - TimeTools::CONFIG[:data_start_time].yday
  end
end
