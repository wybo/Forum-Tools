class HOTTools
  WINDOWS = []
  (0..22).each do |i|
    WINDOWS << [i, i + 1]
  end
  WINDOWS << [23, 0]

  def self.in_time_window(window, time)
    hour = Time.at(time).hour
    if hour == WINDOWS[window][0] or hour == WINDOWS[window][1]
      return true
    else
      return false
    end
  end
end
