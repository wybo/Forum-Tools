require 'open_struct_array'

class Store < OpenStructArray
  alias :array_delete :delete

  def self.all(class_const, file_regexp, &block)
    return super(class_const, 
        ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:yaml_dir],
        file_regexp, &block)
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

class HashStore < Hash
  attr_reader :file_name
  def initialize(file_name, options = {})
    @file_name = file_name
    @yaml_options = options
    if options[:hash]
      self.items = options[:hash]
    else
      self.items = ForumTools::File.read_yaml(@file_name, @yaml_options)
    end
    return self
  end

  def items=(hash)
    hash.keys.each do |key|
      self[key] = hash[key]
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
  def self.all(forum_name = nil, &block)
    if forum_name and forum_name.to_sym == :all
      forum_name = nil
    end
    forum_name ||= "**"
    return Store.all(ThreadStore, forum_name + "/thread*", &block)
  end

  def self.max_hours_on_frontpage(max_hours)
    list = []
    max_hours_sec = max_hours.hours.to_i + 30.minutes.to_i
    self.all.each do |thread|
      if (thread.off_frontpage_time - thread.on_frontpage_time) < max_hours_sec
        list << thread
      end
    end
    return list
  end

  def initialize(options = {})
    if options.kind_of?(String)
      super(options)
    elsif options.kind_of?(Hash)
      super(options[:file_name], options)
      if options[:array]
        self.items = options[:array]
      end
    elsif options.kind_of?(Integer)
      super("thread_" + options.to_s)
    else
      raise 'Invalid options: ' + options.inspect
    end
  end

  def hash
    hash = {}
    self.each do |post|
      hash[post[:id]] = post
    end
    return hash
  end

  def save_json(options = {})
    ForumTools::File.save_json(@file_name, self, options)
  end
end

class ForumsStore < Store
  def self.all_forum_names()
    file_names = OpenStructArray.all_file_names(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:yaml_dir], "*")
    dir_names = []
    file_names.each do |file_name|
      if File.directory?(file_name)
        dir_names << File.basename(file_name)
      end
    end
    return dir_names
  end

  def initialize()
    super("forums")
    @start_time
    @end_time
  end

  def start_time()
    if !@start_time
      @start_time = Time.now.to_i
      self.each do |forum|
        if forum[:start_time] < @start_time
          @start_time = forum[:start_time]
        end
      end
    end
    return @start_time
  end

  def end_time()
    if !@end_time
      @end_time = 0
      self.each do |forum|
        if forum[:end_time] > @end_time
          @end_time = forum[:end_time]
        end
      end
    end
    return @end_time
  end

  def largest(number)
    array = []
    self.each do |forum|
      if (forum[:rank] < number)
        array << forum
      end
    end
    return array
  end

  def smallest(number)
    array = []
    number = self.size - number
    self.each do |forum|
      if (forum[:rank] >= number)
        array << forum
      end
    end
    return array
  end

  def hash
    hash = {}
    self.each do |user|
      hash[user[:name]] = user
    end
    return hash
  end

  def to_yaml
    self.sort! {|a,b| a[:name] <=> b[:name]}
    super
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
    max_variance = 0
    hash.each_pair do |key, times|
      canonical_time = 0
      if times.size > 1
        if times.max - times.min > max_variance
          max_variance = times.max - times.min
          if max_variance > 300
            raise "Variance in time too big #{key}: #{max_variance.to_s}"
          end
        end
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
    puts "max variance: #{max_variance.to_s} seconds"
    array.sort! {|x,y| x[:id] <=> y[:id] }
    # Now make sure times are ordered as well
    for i in 1...(array.size) do
      if array[i][:time] < array[i - 1][:time]
        if array[i] and array[i + 1][:time] > array[i - 1][:time]
          array[i][:time] = TimesStore.id_fraction_time(array[i][:id],
              array[i - 1][:time], array[i + 1][:time],
              array[i - 1][:id], array[i + 1][:id])
        else
          array[i][:time] = array[i - 1][:time]
        end
      end
    end
    max_gap = 0
    last_time_hash = array[0]
    array.each do |time_hash|
      if last_time_hash[:time] - time_hash[:time] > max_gap
        max_gap = last_time_hash[:time] - time_hash[:time]
      end
      last_time_hash = time_hash
    end
    puts "max gap: #{(max_gap / 60.0).ceil.to_s} minutes"
    return TimesStore.new(:array => array)
  end
end

class TimesStore < Store
  def initialize(options = {})
    super("times", :var => true)
    if options[:array]
      self.items = options[:array]
    end
  end

  def time(id)
    i_before = find_before_index(id, 0, self.size - 1)
    if id < self[i_before][:id] or id > self[i_before + 1][:id]
      # out of range 
      # (smaller than first for which data, or larger than last)
      return nil
    end

    return TimesStore.id_fraction_time(id,
        self[i_before][:time], self[i_before + 1][:time],
        self[i_before][:id], self[i_before + 1][:id])
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

  ### Helpers

  def self.id_fraction_time(id, time_before, time_after, id_before, id_after)
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
end

class UsersStore < Store
  def self.user_replies(user)
    return user[:posts] - user[:threads]
  end

  def initialize()
    super("users")
  end

  def hash
    hash = {}
    self.each do |user|
      hash[user[:name]] = user
    end
    return hash
  end

  def prolificity(prolific)
    array = []
    self.each do |user|
      if (prolific and user[:posts] >= ForumTools::CONFIG[:prolific_cutoff]) or
          (!prolific and user[:posts] <= ForumTools::CONFIG[:unprolific_cutdown])
        array << user
      end
    end
    return array
  end

  def prolificity_hash(prolific)
    hash = {}
    self.prolificity(prolific).each do |user|
      hash[user[:name]] = 1
    end
    return hash
  end

  def prolific_hash
    return self.prolificity_hash(true)
  end

  def unprolific_hash
    return self.prolificity_hash(false)
  end

  def posted_once_hash
    hash = {}
    self.each do |user|
      if user[:posts] == 1
        hash[user[:name]] = 1
      end
    end
    return hash
  end

  def to_yaml
    self.sort! {|a,b| a[:name] <=> b[:name]}
    super
  end
end

class PermutationTestStore < Store
  def self.all_pajek_file_names
    list = Dir.glob(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:net_dir] + "x_random_window.*.net")
    return list.sort
  end

  def self.next_file_number
    all_files = self.all_pajek_file_names
    if !all_files.empty?
      return self.file_number(all_files[-1]) + 1
    else
      store = PermutationTestStore.new()
      return store.size
    end
  end

  def self.file_number(file_name)
    base_name = File.basename(file_name)
    return base_name.split(".")[1].to_i
  end

  def initialize()
    super("permutation_test", :var => true)
    @end_time = (ForumTools::CONFIG[:samples][ForumTools::CONFIG[:environment].to_sym][:end_time] + 2.days).to_i
    @days_span = TimeTools.day(@end_time, :start_time => ForumTools::CONFIG[:data_start_time])
  end

  def randomize_windows
    @windows = []
    no_goes = []
    @days_span.times do |i|
      @windows[i] = Kernel.rand(24)
#      begin
#        if i > 0
#          no_goes = TimeTools::WINDOWS[@windows[i - 1]] # counts on 3-hour windows with core in center
#        end
#      end while no_goes.include?(@windows[i])
    end
  end

  def test
    counter_hash = {}
    original_hash = self.original
    original_hash.keys.each do |key|
      counter_hash[key] = 0
    end
    self.each do |hash|
      hash.keys.each do |key|
        if hash[key] >= original_hash[key]
          counter_hash[key] += 1
        end
      end
    end
    results_hash = {}
    original_hash.keys.each do |key|
      results_hash[key] = counter_hash[key] / self.size.to_f
    end
    self.results = results_hash.merge(:size => self.size)
  end

  def in_random_time_window(time)
    window = @windows[TimeTools.day(time, :start_time => ForumTools::CONFIG[:data_start_time])]
    return TimeTools.in_time_window(window, time)
  end
end

class NetworkStore < HashStore
  def self.all_pajek_file_names
    return Dir.glob(ForumTools::CONFIG[:env_dir] + ForumTools::CONFIG[:net_dir] + "*.net")
  end

  def initialize(file_name, options = {})  
    if options[:keep_path]
      super((File.dirname(file_name) + "/" + File.basename(file_name, ".net") + ".yaml"), options)
    else
      super((File.basename(file_name, ".net") + ".yaml"), options.merge(:var => true))
    end
  end

  def users
    users = []
    self.keys.each do |key1|
      users << key1
      self[key1].keys.each do |key2|
        users << key2
      end
    end
    return users.sort.uniq
  end
end

class TimeDifferencesStore < HashStore
  def initialize
    super("time_distances", :var => true)
  end
end
