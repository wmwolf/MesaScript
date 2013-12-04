InlistItem = Struct.new(:name, :type, :default, :namelist, :order)

class Inlist
  
  
  # Establish class instance variables 
  # Different namelists can be added or subtracted if MESA should change or 
  # proprietary inlists are required
  @namelists = %w{ star_job controls pgstar }
  
  # User can add new paths to namelist default files through this hash
  @defaults_paths = Hash.new(ENV['MESA_DIR'] + '/star/defaults/')
  
  # User can specify a custom name for a namelist defaults file. The default
  # is simply the namelist name followed by '.defaults'
  @defaults_names = {}
  
  @inlist_data = {}
  
  # This tells the class to initialize its structure if it hasn't already.
  # If new namelists are added after an instance is initialized, this can be
  # redone manually by the Inlist.get_data command.
  @have_data = false
  
  @already_defined_methods = []
  
  # Set up interface to access/change customizable inlist initialization data.
  class << self
    attr_accessor :namelists, :have_data, :defaults_paths, :defaults_names
    attr_reader :inlist_data
  end
  
  # Generate methods for the Inlist class that set various namelist parameters.
  def self.get_data
    namelists.each do |namelist|
      @inlist_data[namelist] = Inlist.get_namelist_data(namelist,
        defaults_names[namelist])
    end
    @inlist_data.each_value do |namelist_data|
      namelist_data.each do |datum|
        if datum.name =~ /\(/
          Inlist.make_parentheses_method(datum)
        else
          Inlist.make_regular_method(datum)
        end
      end
    end
    Inlist.have_data = true
  end
  
  def self.make_parentheses_method(datum)
    name = datum.name
    base_name = name[0...name.index('(')]
    return nil if @already_defined_methods.index(base_name)
    default_entry = name[(name.index('(') + 1)...name.index(')')]
    define_method(base_name) do |*args|
      value_1 = args[0] || default_entry
      value_2 = args[1] || datum.default
      self[datum.namelist][datum.order] = self[datum.namelist][datum.order] +
        "  " + base_name + '(' + value_1.to_s + ') = ' + 
        Inlist.parse_input(base_name, value_2, datum.type) + "\n"
    end
    alias_method base_name.downcase.to_sym, base_name.to_sym
    @already_defined_methods << base_name
  end
  
  def self.make_regular_method(datum)
    define_method(datum.name) do |*args|
      value = args[0] || datum.default
      name = datum.name
      type = datum.type
      self[datum.namelist][datum.order] =  "  " + datum.name + ' = ' +
                              Inlist.parse_input(name, value, type) + "\n"
    end
    alias_method name.downcase.to_sym, name.to_sym
    alias_method (name + '=').to_sym, name.to_sym
    alias_method (datum.name.downcase + '=').to_sym, datum.name.to_sym
    @already_defined_methods << name
    puts "whoopsie poopsies!" unless defined?(name.to_sym)
  end
    
  
  # Ensure provided value's data type matches expected data type. Then convert
  # to string for printing to an inlist. If value is a string, change nothing 
  # (no protection). If value is a string and SHOULD be a string, wrap it in 
  # single quotes.
  def self.parse_input(name, value, type)
    if value.class == String
      return "'#{value}'" if type == :string 
      return value
    elsif type == :bool
      unless [TrueClass, FalseClass].include?(value.class)
        raise "Invalid value for namelist item #{name}: #{value}. Use " +
        "'.true.', '.false.', or a Ruby boolean (true/false)."
      end
      if value == true
        return '.true.'
      elsif value == false
        return '.false.'
      else
        raise "Error converting value #{value} of #{name} to a boolean."
      end
    elsif type == :float or type == :int
      raise "Invalid value for namelist item #{name}: #{value}. Must provide " +
      "an int or float." unless value.is_a?(Integer) or value.is_a?(Float)
      return sprintf("%g", value).sub('e', 'd')
    else
      raise "Error parsing value for namelist item #{name}: #{value}."
    end
  end

  # Create an Inlist object, execute block of commands that presumably populate
  # the inlist, then write the inlist to a file with the given name.
  def self.make_inlist(name = 'inlist', &block)
    inlist = Inlist.new
    inlist.instance_eval(&block)
    File.open(name, 'w') { |f| f.write(inlist) }
  end
  
  # Checks to see if the data/methods for the Inlist class has been initialized.
  def self.have_data?
    @have_data
  end
  
  # Reads names and default values for a specified namelist. Assumes namelist
  # is named "#{namelist}.defaults" or is provided as the second argument. Also
  # assumes that file is located in Inlist.defaults_paths[namelist].
  #
  # Ignores all blank lines and comment lines, and assumes that all other lines
  # are of the form NAME = VALUE. Assumes all values are logicals, strings (with
  # single quotes only), floats (contains a decimal, a d, or a D), or an integer
  # (just numerals, no decimals or letters). Currently the distincion between
  # floats and integers is meaningless.
  #
  # Returns an array of InlistItem Struct instanc that contain a parameter's
  # name, type (:bool, :string, :float, or :int), default value (as a string),
  # the namelist it belongs to, and its relative ordering in that namelist.
  def self.get_namelist_data(namelist, filename = nil)
    file_name ||= namelist + '.defaults'
    full_path = Inlist.defaults_paths[namelist] + file_name
    raise "Couldn't find file #{file_name}" unless File.exists?(full_path)
    contents = File.readlines(full_path)
    contents.reject! { |line| is_comment?(line) or is_blank?(line) }
    contents.map! do |line|
      my_line = line.dup
      if has_comment?(line)
        my_line = my_line[0...my_line.index('!')]
      end
      raise "Equal sign missing in line:\n\t #{my_line}\n in file " +
        "#{full_path}." unless my_line =~ /=/
      my_line.strip!
    end
    pairs = contents.map {|line| line.split('=').map {|datum| datum.strip}}
    namelist_data = pairs.each_with_index.map do |pair, i|
      name = pair[0]
      default = pair[1]
      if %w{ .true. .false. }.include?(default)
        type = :bool
      elsif default =~ /\A\'.*\'/
        type = :string
      elsif default =~ /[\.dD]/
        type = :float
      elsif default =~ /[0-9]+/
        type = :int
      else
        raise "Couldn't determine type for default value of #{name}: " +
              "#{default} in #{full_path}."
      end
      InlistItem.new(name, type, default, namelist, i)
    end
  end
  
  def self.is_comment?(line)
    line =~ /\A\s*!/
  end

  def self.is_blank?(line)
    not (line =~/[a-z0-9]+/)
  end

  def self.has_comment?(line)
    line.include?('!')
  end

  # Making an instance of Inlist first checks to see if the class methods are 
  # set up for the namelists in Inlist.namelists. If they aren't ready, it
  # creates them. Then creates a hash with an array associated to each namelist
  # that is the exact size of the number of entries available in that namelist.
  def initialize
    Inlist.get_data unless Inlist.have_data?
    @data = {}
    Inlist.namelists.each do |namelist|
      @data[namelist] = Array.new(Inlist.inlist_data[namelist].size, '')
    end
  end
  
  def [](namelist)
    @data[namelist]
  end
  
  def namelists
    @data.keys
  end

  def to_s
    result = ''
    namelists.each do |namelist|
      result += "\n&#{namelist}\n"
      result += self[namelist].join("")
      result += "\n/ ! end of #{namelist} namelist\n"
    end
    result
  end
  
  # This method SHOULD be private, but it is used by the class methods, so it
  # has to be public lest we use some uglier "send" syntax. DON'T USE THIS.
  def []=(namelist, value)
    @data[namelist] = value
  end
  
end

