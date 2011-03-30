require 'open_struct_array'

class Store < OpenStructArray
  def self.all(class_const, file_regexp)
    return super(class_const, 
        ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:yaml_dir] + file_regexp)
  end

  def initialize(file_name, options = {})
    super(file_name)
    @yaml_options = options
    self.from_hash(ForumTools::File.read_yaml(@file_name, @yaml_options))
    return self
  end

  def from_hash(structure)
    structure.each_pair do |key, value|
      self.send(key.to_s + '=', value)
    end
  end

  def save
    ForumTools::File.save_yaml(@file_name, self, @yaml_options)
  end

  def delete
    ForumTools::File.delete_yaml(@file_name, @yaml_options)
  end
end

class ThreadStore < Store
  def self.all
    return Store.all(ThreadStore, "thread*")
  end

  def initialize(options = {})
    if options.kind_of?(String)
      super(options)
    elsif options.kind_of?(Integer)
      super("thread_" + options.to_s)
    else
      raise 'Invalid options: ' + options.inspect
    end
  end
end

class AllTimesStore < Store
  def initialize()
    super("all_times", :var => true)
  end

  def add_times(items)
    items.each do |item|
      if item[:time_string] =~ /minute/
        self << {:id => item[:id], :time => item[:time]}
      end
    end
  end

  def to_canonical_times
    hash = {}
    self.each do |item|
      if !hash[item[:id]]
        hash[item[:id]] = []
      end
      hash[item[:id]].push(item[:time])
    end
    array = []
    hash.each_pair do |key, times|
      canonical_time = 0
      if times.size > 1
        adder = 0
        times.each do |time|
          adder += time
        end
        canonical_time = adder / times.size
      else
        canonical_time = times[0]
      end
      array.push({:id => key, :time => canonical_time})
    end
    array.sort! {|x,y| x[:id] <=> y[:id] }
    return TimesStore.new(:array => array)
  end
end

class TimesStore < Store
  def initialize(options = {})
    super("times", :var => true)
    if options[:array]
      clear()
      options[:array].each do |item|
        self << item
      end
    end
  end

  def time(id)
    i_before = find_before_index(id, 0, self.size - 1)
    if id < self[i_before][:id] or id > self[i_before + 1][:id]
      # out of range 
      # (smaller than first for which data, or larger than last)
      return nil
    end
    id_before = self[i_before][:id]
    id_after = self[i_before + 1][:id]
    time_before = self[i_before][:time]
    time_after = self[i_before + 1][:time]

    id_gap = id_after - id_before
    #    gap = B <------------------> A
    id_offset = id - id_before
    # offset = B <--------------> Id
    fraction = (id_offset * 1.0) / id_gap
    #  fract = offset / gap = 0.8
    time_gap = time_after - time_before
    time = time_before + (time_gap * fraction).to_i
    return time
  end

  def find_before_index(id, i_start, i_end)
    if i_end - i_start < 2
      return i_start
    end
    middle = (i_start + i_end) / 2
    if self[middle][:id] < id
      find_before_index(id, middle, i_end)
    else
      find_before_index(id, i_start, middle)
    end
  end
end

class UserStore < Store
  def self.all
    return Store.all(ThreadStore, "user*")
  end

  def initialize(options = {})
    if options.kind_of?(String)
      if options =~ /^user_/
        super(options)
      else
        super("user_" + options)
      end
    else
      raise 'Invalid options: ' + options.inspect
    end
  end
end

