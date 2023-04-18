InlistItem = Struct.new(:name, :type, :value, :namelist, :order, :is_arr,
                        :num_indices, :flagged)
def namelist_sym(namelist)
  namelist.to_s.downcase.to_sym
end

class Inlist

  # check if this version came from a github repository (newer than 15140)
  def self.version_is_git?
    File.exist?(File.join(ENV['MESA_DIR'], '.gitignore')) or File.exist?(File.join(ENV['MESA_DIR'], '.github'))
  end

  # Get access to current MESA version.
  def self.version
    IO.read(File.join(ENV['MESA_DIR'], 'data', 'version_number')).sub('.', '').sub('r', '')
  end

  # Determine proper file suffix for fortran source
  def self.f_end
    if Inlist.version_is_git? || Inlist.version.to_i >= 7380
      'f90'
    else
      'f'
    end
  end

  # Determine proper file location for star-related .inc files
  def self.star_or_star_data
    if Inlist.version_is_git? || Inlist.version.to_i >= 12245
      'star_data'
    else
      'star'
    end
  end

  # these hold the names of the namelists as well as the locations of the
  # fortran files that define their controls as well as the defaults files
  # that define their default values and order in formatted inlists
  @namelists = []
  @source_files = Hash.new([])
  @defaults_files = {}

  # this holds the "guts"; control names, types, defaults, and orders
  @inlist_data = {}

  # used to turn on a namelist; need to provide namelist name as well as
  # locations for source file (usually a .inc or .f90 file that defines
  # allowable controls) and a defaults file (usually a .defaults file that
  # lists all controls and their default values). Shorthand versions for
  # the three common star namelists and the one common binary namelist are
  # defined below for convenience
  def self.config_namelist(namelist: nil, source_files: nil,
                           defaults_file: nil, verbose: true)
    new_namelist = namelist_sym(namelist)
    add_namelist(new_namelist)
    set_source_files(new_namelist, source_files)
    set_defaults_file(new_namelist, defaults_file)
    return unless verbose
    puts 'Added the following namelist data:'
    puts "  namelist: #{new_namelist}"
    puts "    source: #{@source_files[new_namelist].join(', ')}"
    puts "  defaults: #{@defaults_files[namelist_sym(namelist)]}"
    puts "Did not load data yet, though.\n\n"
  end

  def self.add_namelist(new_namelist)
    if new_namelist.nil? || new_namelist.empty?
      raise(NamelistError.new, 'Must provide a namelist name.')
    end
    return if @namelists.include? namelist_sym(new_namelist)
    @namelists << namelist_sym(new_namelist)
  end

  def self.set_source_files(namelist, new_sources)
    # set source files. There may be more than one, so we ALWAYS make it an
    # array. Flatten magic allows for users to supply an array or a scalar
    # (single string)
    if new_sources.nil? || new_sources.empty?
      raise NamelistError.new,
            "Must provide a source file for namelist #{namelist}. For " \
            'example, $MESA_DIR/star/private/star_job_controls.inc for ' \
            'star_job.'
    end
    source_to_add = if new_sources.respond_to?(:map)
                      new_sources.map(&:to_s)
                    else
                      new_sources.to_s
                    end
    @source_files[namelist_sym(namelist)] = [source_to_add].flatten
  end

  def self.set_defaults_file(namelist, new_defaults_file)
    # set defaults file. This is limited to being scalar string for now.
    return unless new_defaults_file
    @defaults_files[namelist_sym(namelist)] = new_defaults_file.to_s
  end

  # Delete all namelists and associated data.
  def self.delete_all_namelists
    namelists.each { |namelist| remove_namelist(namelist) }
    @have_data = false
  end

  # delete namelist and associated data
  def self.delete_namelist(namelist)
    to_delete = namelist_sym(namelist)
    found_something = namelists.delete(to_delete)
    found_something = delete_files(to_delete) || found_something
    # this also undefines methods
    found_something = delete_data(to_delete) || found_something
    unless found_something
      puts "WARNING: Attempting to delete namelist #{namelist} data, but it " \
           "wasn't present in existing Inlist data. Nothing happened."
    end
    namelist
  end

  # just remove associated source and defaults files; don't touch underlying
  # data or methods (if any exist yet)
  def self.delete_files(namelist)
    found_something = false
    [source_files, defaults_files].each do |files|
      found_something ||= files.delete(namelist_sym(namelist))
    end
    found_something
  end

  # see if data has been loaded, and if it has, delete all the methods
  # associated with it and then wipe the data, too.
  def self.delete_data(namelist)
    to_delete = namelist_sym(namelist)
    return false unless inlist_data.include? namelist_sym(to_delete)
    delete_methods(to_delete)
    inlist_data.delete(to_delete)
  end

  # just delete the methods. This will throw errors if they don't exist
  def self.delete_methods(namelist)
    @inlist_data[namelist_sym(namelist)].each { |datum| delete_method(datum) }
  end

  # short hand for adding star_job namelist using sensible defaults as of 10108
  def self.add_star_job_defaults(verbose: false)
    config_namelist(
      namelist: :star_job,
      source_files: File.join(ENV['MESA_DIR'], star_or_star_data, 'private',
                              'star_job_controls.inc'),
      defaults_file: File.join(ENV['MESA_DIR'], 'star', 'defaults',
                               'star_job.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding controls namelist using sensible defaults as of 10108
  def self.add_controls_defaults(verbose: false)
    config_namelist(
      namelist: :controls,
      source_files: [File.join(ENV['MESA_DIR'], star_or_star_data, 'private',
                               'star_controls.inc'),
                     File.join(ENV['MESA_DIR'], 'star', 'private',
                               "ctrls_io.#{f_end}")],
      defaults_file: File.join(ENV['MESA_DIR'], 'star', 'defaults',
                               'controls.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding kap namelist using sensible defaults as of 22.11.1
  def self.add_kap_defaults(verbose: false)
    config_namelist(
      namelist: :kap,
      source_files: [File.join(ENV['MESA_DIR'], 'kap', 'private',
                               "kap_ctrls_io.#{f_end}"),
      defaults_file: File.join(ENV['MESA_DIR'], 'kap', 'defaults',
                               'kap.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding eos namelist using sensible defaults as of 22.11.1
  def self.add_eos_defaults(verbose: false)
    config_namelist(
      namelist: :eos,
      source_files: [File.join(ENV['MESA_DIR'], 'eos', 'private',
                               "eos_ctrls_io.#{f_end}"),
      defaults_file: File.join(ENV['MESA_DIR'], 'eos', 'defaults',
                               'eos.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding pgstar namelist using sensible defaults as of 10108
  def self.add_pgstar_defaults(verbose: false)
    config_namelist(
      namelist: :pgstar,
      source_files: File.join(ENV['MESA_DIR'], star_or_star_data, 'private',
                              'pgstar_controls.inc'),
      defaults_file: File.join(ENV['MESA_DIR'], 'star', 'defaults',
                               'pgstar.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding binary_controls_defaults namelist using sensible
  # defaults as of 10108
  def self.add_binary_controls_defaults(verbose: false)
    config_namelist(
      namelist: :binary_controls,
      source_files: File.join(ENV['MESA_DIR'], 'binary', 'public',
                              'binary_controls.inc'),
      defaults_file: File.join(ENV['MESA_DIR'], 'binary', 'defaults',
                               'binary_controls.defaults'),
      verbose: verbose
    )
  end

  # short hand for adding binary_job_defaults namelist using sensible defaults
  # as of 10108
  def self.add_binary_job_defaults(verbose: false)
    config_namelist(
      namelist: :binary_job,
      source_files: File.join(ENV['MESA_DIR'], 'binary', 'private',
                              'binary_job_controls.inc'),
      defaults_file: File.join(ENV['MESA_DIR'], 'binary', 'defaults',
                               'binary_job.defaults'),
      verbose: verbose
    )
  end

  # quickly add all five (three for older versions) major namelists for star
  # module (star_job, controls, and pgstar)
  def self.add_star_defaults
    add_star_job_defaults
    if Inlist.version_is_git? || Inlist.version.to_i > 15140
      add_kap_defaults
      add_eos_defaults
    end
    add_controls_defaults
    add_pgstar_defaults
  end

  # quickly add both major namelists for binary module (binary_job and
  # binary_controls)
  def self.add_binary_defaults
    add_binary_job_defaults
    add_binary_controls_defaults
  end

############### NO MORE [SIMPLE] USER-CUSTOMIZABLE FEATURES BELOW ##############

  # This tells the class to initialize its structure if it hasn't already.
  # If new namelists are added after an instance is initialized, this can be
  # redone manually by the Inlist.get_data command.
  @have_data = false

  # Set up interface to access/change customizable inlist initialization data.
  # Establish class instance variables
  class << self
    attr_accessor :have_data
    attr_accessor :namelists, :source_files, :defaults_files, :inlist_data
  end

  # Generate methods for the Inlist class that set various namelist parameters.
  def self.get_data(use_star_as_fallback: true)
    # might need to add star data; preserves expected behavior (minus binary)
    Inlist.add_star_defaults if use_star_as_fallback && Inlist.namelists.empty?
    Inlist.namelists.each do |namelist|
      @inlist_data[namelist] = Inlist.get_namelist_data(namelist)
    end
    # create methods (interface) for each data category
    @inlist_data.each_value do |namelist_data|
      namelist_data.each { |datum| Inlist.make_method(datum) }
    end
    # don't do this nonsense again unles specifically told to do so
    Inlist.have_data = true
  end

  def self.make_method(datum)
    if datum.is_arr
      Inlist.make_parentheses_method(datum)
    else
      Inlist.make_regular_method(datum)
    end
  end

  def self.delete_method(datum)
    if datum.is_arr
      Inlist.delete_parentheses_method(datum)
    else
      Inlist.delete_regular_method(datum)
    end
  end

  # Three ways to access array categories. All methods will cause the
  # data category to be staged into your inlist, even if you do not change it
  # Basically, if it appears in your mesascript, it will definitely appear
  # in your inlist. A command can be unflagged by calling
  # `unflag_command('COMMAND_NAME')` where COMMAND_NAME is the case-sensitive
  # name of the command to be unflagged.
  #
  # 1. Standard array way like
  #        xa_lower_limit_species[1] = 'h1'
  #    (note square braces, NOT parentheses). Returns new value.
  #
  # 2. Just access (and flag), but don't change via array access, like
  #        xa_lower_limit_species[1]
  #    (again, note square braces). Returns current value
  #
  # 3. No braces method, like
  #        xa_lower_limit_species()           # flags and returns hash of values
  #        xa_lower_limit_species             # same, but more ruby-esque
  #        xa_lower_limit_species(1)          # flags and returns value 1
  #        xa_lower_limit_species 1           # Same
  #        xa_lower_limit_species(1, 'h1')    # flags and sets value 1
  #        xa_lower_limit_species 1, 'h1'     # same
  #
  # For multi-dimensional arrays, things are even more vaired. You can treat
  # them like 1-dimensional arrays with the "index" just being an array of
  # indices, for instance:
  #
  #        text_summary1_name[[1,2]] = 'star_mass' # flags ALL values and sets
  #        text_summary1_name([1,2], 'star_mass')  # text_summary1_name(1,2)
  #        text_summary1_name [1,2], 'star_mass    # to 'star_mass'
  #
  #        text_summary1_name [1,2]                # flags ALL values and
  #        text_summary1_name([1,2])               # returns
  #                                                # text_sumarry_name(1,2)
  #
  #        text_summary_name()                     # flags ALL values and
  #        text_summary_name                       # returns entire hash for
  #                                                # text_summary_name
  #
  # Alternatively, can use the more intuitive form where indices are separate
  # and don't need to be in an array, but this only works with the parentheses
  # versions (i.e. the first option directly above has no counterpart):
  #
  #        text_summary1_name(1, 2, 'star_mass')
  #        text_summary1_name 1, 2, 'star_mass'    # same as above (first 3)
  #
  #        text_summary1_name

  def self.make_parentheses_method(datum)
    method_name = datum.name
    num_indices = datum.num_indices

    # assignment array form
    define_method(method_name + '[]=') do |arg1, arg2|
      if num_indices > 1
        unless arg1.is_a?(Array) && arg1.length == num_indices
          raise "First argument of #{method_name}[]= (part in brackets) must "\
                "be an array with #{num_indices} indices since #{method_name}"\
                ' is a multi-dimensional array.'
        end
      end
      flag_command(method_name)
      data_hash[method_name].value[arg1] = arg2
    end

    # de-referencing array form
    define_method(method_name + '[]') do |arg|
      if num_indices > 1
        unless arg.is_a?(Array) && arg.length == num_indices
          raise "Argument of #{method_name}[] (part in brackets) must be an " \
                "array with #{num_indices} indices since #{method_name} is a "\
                'multi-dimensional array.'
        end
      end
      flag_command(method_name)
      data_hash[method_name].value[arg]
    end

    # imperative multi-purpose form
    define_method(method_name) do |*args|
      flag_command(method_name)
      case args.length
      # just retrieve whole value (de-reference)
      when 0 then data_hash[method_name].value
      # just retrieve part of value (de-reference)
      when 1
        if num_indices > 1
          unless args[0].is_a?(Array) && args[0].length == num_indices
            raise "First argument of #{method_name} must be an array with " \
                  "#{num_indices} indices since #{method_name} is a " \
                  'multi-dimensional array OR must provide all indices as ' \
                  'separate arguments.'
          end
        end
        data_hash[method_name].value[args[0]]
      # might be trying to access or a multi-d array OR assign to an array.
      when 2
        # 1-D array with scalar value; simple assignement
        if num_indices == 1 && !args[0].is_a?(Array)
          data_hash[method_name].value[args[0]] = args[1]
        # 2-D array, de-reference single value (NOT AN ASSIGNMENT!)
        elsif num_indices == 2 && !args[0].is_a?(Array) &&
              args[1].is_a?(Integer)
          data_hash[method_name].value[args]
        # Multi-d array with first argument being an array, second a value to
        # assign; simple assignment
        elsif num_indices > 1
          unless args[0].is_a?(Array) && args[0].length == num_indices
            raise "First argument of #{method_name} must be an array with " \
                  "#{num_indices} indices since #{method_name} is a " \
                  'multi-dimensional array OR must provide all indices as ' \
                  'separate arguments.'
          end
          data_hash[method_name].value[args[0]] = args[1]
        # Can't parse... throw hands up.
        else
          raise "First argument of #{method_name} must be an array with "\
                "#{num_indices} indices since #{method_name} is a "\
                'multi-dimensional array OR must provide all indices as '\
                'separate arguments. The optional final argument is what the '\
                "#{method_name} would be set to. Omission of this argument "\
                "will simply flag #{method_name} to appear in the inlist."
        end
      # one more argument than number of indices; first n are location to be
      # assigned, last one is value to be assigned
      when num_indices + 1
        if args[0].is_a?(Array)
          raise "Bad arguments for #{method_name}. Either provide an array " \
                "of #{num_indices} indices for the first argument or provide "\
                'each index in succession, optionally specifying the desired '\
                'value for the last argument.'
        end
        data_hash[method_name].value[args[0..-2]] = args[-1]
      # same number of arguments as indices; assume we are de-referencing a
      # value
      when num_indices then data_hash[method_name].value[args]
      # give up... who knows what the user is doing?!
      else
        raise "Wrong number of arguments for #{method_name}. Can provide " \
              'zero arguments (just flag command), one argument (array of ' \
              'indices for multi-d array or one index for 1-d array), two ' \
              'arguments (array of indices/single index for multi-/1-d array '\
              'and a new value for the value), #{num_indices} arguments ' \
              'where the elements themselves are the right indices (returns ' \
              "the specified element of the array), or #{num_indices + 1} " \
              'arguments to set the specific value and return it.'
      end
    end
    alias_method method_name.downcase.to_sym, method_name.to_sym
    alias_method((method_name.downcase + '[]').to_sym,
                 (method_name + '[]').to_sym)
    alias_method((method_name.downcase + '[]=').to_sym,
                 (method_name + '[]=').to_sym)
  end

  def self.delete_parentheses_method(datum)
    base_name = datum.name
    method_names = [base_name, base_name + '[]', base_name + '[]=']
    alias_names = method_names.map(&:downcase)
    [method_names, alias_names].flatten.uniq.each { |meth| remove_method(meth) }
  end

  # Two ways to access/change scalars. All methods will cause the data category
  # to be staged into your inlist, even if you do not change the value.
  # Basically, if it appears in your mesascript, it will definitely appear in
  # your inlist.
  #
  # 1. Change value, like
  #        initial_mass(1.0)
  #        initial_mass 1.0
  #    This flags the category to go in your inlist and changes the value. There
  #    is no difference between these two syntaxes (it's built into ruby).
  #    Returns new value.
  #
  # 2. Just access, like
  #        initial_mass()
  #        initial_mass
  #    This flags the category, but does not change the value. Again, both
  #    syntaxes are allowed, though the one without parentheses is more
  #    traditional for ruby (why do you want empty parentheses anyway?). Returns
  #    current value.
  #
  # A command can be unflagged by calling `unflag_command('COMMAND_NAME')`
  # where COMMAND_NAME is the case-sensitive name of the command to be
  # unflagged.

  def self.make_regular_method(datum)
    method_name = datum.name
    define_method(method_name) do |*args|
      self.flag_command(method_name)
      return self.data_hash[method_name].value if args.empty?
      self.data_hash[method_name].value = args[0]
    end
    aliases = [(method_name + '=').to_sym,
               (method_name.downcase + '=').to_sym,
               method_name.downcase.to_sym]
    aliases.each { |ali| alias_method ali, method_name.to_sym }
  end

  def self.delete_regular_method(datum)
    method_name = datum.name
    aliases = [method_name + '=',
               method_name.downcase + '=',
               method_name.downcase]
    [method_name, aliases].flatten.uniq.each { |meth| remove_method meth }
  end

  # Ensure provided value's data type matches expected data type. Then convert
  # to string for printing to an inlist. If value is a string, change nothing
  # (no protection). If value is a string and SHOULD be a string, wrap it in
  # single quotes.
  def self.parse_input(name, value, type)
    if value.class == String
      if type == :string
        value = "'#{value}'" unless value[0] == "'" && value[-1] == "'"
      end
      value
    elsif type == :bool
      unless [TrueClass, FalseClass].include?(value.class)
        raise "Invalid value for namelist item #{name}: #{value}. Use " \
              "'.true.', '.false.', or a Ruby boolean (true/false)."
      end
      if value == true
        '.true.'
      elsif value == false
        '.false.'
      else
        raise "Error converting value #{value} of #{name} to a boolean."
      end
    elsif type == :int
      unless value.is_a?(Integer) || value.is_a?(Float)
        raise "Invalid value for namelist item #{name}: #{value}. Must " \
              'provide an int or float.'
      end
      if value.is_a?(Float)
        puts "WARNING: Expected integer for #{name} but got #{value}. Value" \
             ' will be converted to an integer.'
      end
      value.to_i.to_s
    elsif type == :float
      unless value.is_a?(Integer) || value.is_a?(Float)
        raise "Invalid value for namelist item #{name}: #{value}. Must "\
              'provide an int or float.'
      end
      res = format('%g', value).sub('e', 'd')
      res += 'd0' unless res.include?('d')
      res
    elsif type == :type
      puts "WARNING: 'type' values are currently unsupported " \
           "(regarding #{name}) because your humble author has no idea what " \
           'they look like in an inlist. You should tell him what to do at ' \
           "wmwolf@asu.edu. Your input, #{value}, has been passed through to "\
           'your inlist verbatim.'
      value.to_s
    else
      raise "Error parsing value for namelist item #{name}: #{value}. " \
            "Expected type was #{type}."
    end
  end

  # Converts a standard inlist to its equivalent mesascript formulation.
  # Comments are preserved and namelist separators are converted to comments.
  # Note that comments do NOT get put back into the fortran inlist through
  # mesascript. Converting an inlist to mesascript and then back again will
  # clean up and re-order your inlist, but all comments will be lost. All other
  # information SHOULD remain intact.
  def self.inlist_to_mesascript(inlist_file, script_file, dbg = false)
    Inlist.get_data unless Inlist.have_data # ensure we have inlist data
    inlist_contents = File.readlines(inlist_file)

    # make namelist separators comments
    new_contents = inlist_contents.map do |line|
      case line
      when /^\s*&/  then '# ' + line.chomp        # start namelist
      when /^\s*\// then '# ' + line.chomp        # end namelist
      else
        line.sub('!', '#').chomp                  # fix comments
      end
    end
    new_contents.map! do |line|
      if line =~ /^\s*#/ or line.strip.empty?     # leave comments and blanks
        result = line
      else
        if dbg
          puts "parsing line:"
          puts line
        end
        comment_pivot = line.index('#')
        if comment_pivot
          command = line[0...comment_pivot]
          comment = line[comment_pivot..-1].to_s.strip
        else
          command = line
          comment = ''
        end
        command =~ /(^\s*)/                       # save leading space
        leading_space = Regexp.last_match(1)
        command =~ /(\s*$)/                       # save buffer space
        buffer_space = Regexp.last_match(1)
        command.strip!                            # remove white space
        name, value = command.split('=').map(&:strip)
        if dbg
          puts "name: #{name}"
          puts "value: #{value}"
        end
        if name =~ /\((\d+)\)/                    # fix 1D array assignments
          name.sub!('(', '[')
          name.sub!(')', ']')
          name += ' ='
        elsif name =~ /\((\s*\d+\s*,\s*)+\d\s*\)/ # fix multi-D arrays
          # arrays become hashes in MesaScript, so rather than having multiple
          # indices, the key becomes the array of indices themselves, hence
          # the double braces replacing single parentheses
          name.sub!('(', '[[')
          name.sub!(')', ']]')
          name += ' ='
        end
        name.downcase!
        result = if value =~ /'.*'/ || value =~ /".*"/
                    name + ' ' + value # leave strings alone
                  elsif %w[.true. .false.].include?(value.downcase)
                    name + ' ' + value.downcase.delete('.') # fix booleans
                  elsif value =~ /\d+\.?\d*([eEdD]\d+)?/
                    name + ' ' + value.downcase.sub('d', 'e') # fix floats
                  else
                    name + ' ' + value # leave everything else alone
                  end
        result = leading_space + result + buffer_space + comment
        if dbg
          puts 'parsed to:'
          puts result
          puts ''
        end
      end
      result
    end
    File.open(script_file, 'w') do |f|
      f.puts "require 'mesa_script'"
      f.puts ''
      f.puts "Inlist.make_inlist('#{File.basename(inlist_file)}') do"
      new_contents.each { |line| f.puts '  ' + line }
      f.puts 'end'
    end
  end

  # Create an Inlist object, execute block of commands that presumably populate
  # the inlist, then write the inlist to a file with the given name. This is
  # the money routine with user-supplied commands in the instance_eval block.
  def self.make_inlist(name = 'inlist', &block)
    inlist = Inlist.new
    inlist.instance_eval(&block)
    inlist.stage_flagged
    File.open(name, 'w') { |f| f.write(inlist) }
  end

  # Checks to see if the data/methods for the Inlist class has been initialized.
  def self.have_data?
    @have_data
  end

  # Reads names and types for a specified namelist from given file (intended
  # to be of the form of something like star/private/star_controls.inc).
  #
  # Returns an array of InlistItem Struct instances that contain a parameter's
  # name, type (:bool, :string, :float, :int, or :type), the namelist it
  # belongs to, and its relative ordering in that namelist. Bogus defaults are
  # assigned according to the object's type, and the ordering is unknown.

  def self.get_namelist_data(namelist)
    temp_data = Inlist.get_names_and_types(namelist)
    Inlist.get_defaults(temp_data, namelist)
  end

  def self.get_names_and_types(namelist)
    namelist_data = []

    source_files[namelist].each do |source_file|
      raise "Couldn't find file #{source_file}" unless File.exist?(source_file)
      contents = File.readlines(source_file)

      # Throw out comments and blank lines, ensure remaining lines are a proper
      # Fortran assignment, then remove leading and trailing white space
      contents.reject! { |line| is_comment?(line) || is_blank?(line) }
      contents.map! do |line|
        my_line = line.dup
        my_line = my_line[0...my_line.index('!')] if has_comment?(my_line)
        my_line.strip!
      end
      full_lines = []
      contents.each_with_index do |line, i|
        break if line =~ /\A\s*contains/
        next unless line =~ /::/
        full_lines << Inlist.full_line(contents, i)
      end
      pairs = full_lines.map do |line|
        line.split('::').map(&:strip)
      end
      pairs.each do |pair|
        type = case pair[0]
               when /logical/ then :bool
               when /character/ then :string
               when /real/ then :float
               when /integer/ then :int
               when /type/ then :type
               else
                 raise "Couldn't determine type of entry #{pair[0]} in " \
                       "#{source_file}."
               end
        name_chars = pair[1].split('')
        names = []
        paren_level = 0
        name_chars.each do |char|
          if paren_level > 0 && char == ','
            names << '!'
            next
          elsif char == '('
            paren_level += 1
          elsif char == ')'
            paren_level -= 1
          end
          names << char
        end
        names = names.join.split(',').map(&:strip)
        names.each do |name|
          is_arr = false
          num_indices = 0
          if name =~ /\(.*\)/
            is_arr = true
            num_indices = name.count('!') + 1
            name.sub!(/\(.*\)/, '')
          elsif pair[0] =~ /dimension\((.*)\)/i
            is_arr = true
            num_indices = Regexp.last_match[1].count(',') + 1
          end
          type_default = { bool: false, string: '', float: 0.0, int: 0 }
          dft = is_arr ? Hash.new(type_default[type]) : type_default[type]
          namelist_data << InlistItem.new(name, type, dft, namelist, -1, is_arr,
                                          num_indices)
        end
      end
    end
    namelist_data
  end

  # Similar to Inlist.get_names_and_types, but takes the output of
  # Inlist.get_names_and_types and assigns defaults and orders to each item.
  # Looks for this information in the specified defaults filename.

  def self.get_defaults(temp_data, namelist, whine = false)
    defaults_file = defaults_files[namelist]
    unless File.exist?(defaults_file)
      raise "Couldn't find file #{defaults_file}"
    end
    contents = File.readlines(defaults_file)
    # throw out comments and blank lines
    contents.reject! { |line| is_comment?(line) || is_blank?(line) }
    # remaining lines should only be assignments. Only use the part of the line
    # up to the comment character, then strip all whitespace
    contents.map! do |line|
      my_line = line.dup
      my_line = my_line[0...my_line.index('!')] if has_comment?(line)
      unless my_line =~ /=/
        raise "Equal sign missing in line:\n\t #{my_line}\n in file " \
              "#{full_path}."
      end
      my_line.strip!
    end
    # divide lines into two element arrays: name and value
    pairs = contents.map { |line| line.split('=').map(&:strip) }
    n_d_hash = {} # maps names to default values
    n_o_hash = {} # maps names to default order in inlist
    pairs.each_with_index do |pair, i|
      name = pair[0]
      default = pair[1]
      # look for parentheses in name, indicating an array
      if name =~ /\(.*\)/
        # make selector be the stuff in the parentheses
        selector = name[/\(.*\)/][1..-2]
        # make name just be the part without parentheses
        name.sub!(/\(.*\)/, '')
        # colon indicates mass assignment
        if selector.include?(':')
          default = Hash.new(default)
        # lack of a comma indicates dimension = 1
        elsif selector.count(',').zero?
          default = { selector.to_i => default }
        # at least one comma, so dimension > 1
        else
          # reformat the selector (now a key in the default hash) to an
          # array of integers
          selector = selector.split(',').map { |index| index.strip.to_i }
          default = { selector => default }
        end
      end
      # if the default value is a hash, we probably don't have every possible
      # value, so just merge scraped values with the automatically chosen
      # defaults
      if n_d_hash[name].is_a?(Hash)
        n_d_hash[name].merge!(default)
      # scalar values get a simple assignment
      else
        n_d_hash[name] = default
      end
      # order is just the same as the order it appeared in its defaults file
      n_o_hash[name] ||= i
    end
    temp_data.each do |datum|
      unless n_d_hash.key?(datum.name)
        if whine
          puts "WARNING: no default found for control #{datum.name}. Using " \
               'standard defaults.'
        end
      end
      default = n_d_hash[datum.name]
      datum.value = if default.is_a?(Hash) && datum.value.is_a?(Hash)
                      datum.value.merge(default)
                    else
                      default || datum.value
                    end
      datum.order = n_o_hash[datum.name] || datum.order
    end
    temp_data
  end

  def self.full_line(lines, indx)
    return lines[indx] unless lines[indx][-1] == '&'
    [lines[indx].sub('&', ''), full_line(lines, indx + 1)].join(' ')
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

  attr_accessor :data_hash
  attr_reader :names
  def initialize(use_star_as_fallback: true)
    unless Inlist.have_data?
      Inlist.get_data(use_star_as_fallback: use_star_as_fallback)
    end
    @data = Inlist.inlist_data
    @data_hash = {}
    @data.each_value do |namelist_data|
      namelist_data.each do |datum|
        @data_hash[datum.name] = datum.dup
      end
    end
    @names = @data_hash.keys
    @data = {}
    Inlist.namelists.each do |namelist|
      @data[namelist] = Array.new(Inlist.inlist_data[namelist].size, '')
    end
  end

  # Zeroes out all staged data and blank lines
  def make_fresh_writelist
    @to_write = {}
    @data.keys.each do |namelist|
      @to_write[namelist] = Array.new(@data[namelist].size, '')
    end
  end

  def namelists
    @data.keys
  end

  def flag_command(name)
    @data_hash[name].flagged = true
  end

  def unflag_command(name)
    @data_hash[name].flagged = false
  end

  def stage_namelist_command(name)
    datum = @data_hash[name]
    if datum.is_arr
      lines = @data_hash[name].value.keys.map do |key|
        prefix = "  #{datum.name}("
        suffix = ') = ' +
                 Inlist.parse_input(datum.name, datum.value[key], datum.type) +
                 "\n"
        indices = if key.respond_to?(:inject)
                    key[1..-1].inject(key[0].to_s) do |res, elt| 
                      "#{res}, #{elt}"
                    end
                  else
                    key.to_s
                  end
        prefix + indices + suffix
      end
      lines = lines.join
      @to_write[datum.namelist][datum.order] = lines
    else
      @to_write[datum.namelist][datum.order] = '  ' + datum.name + ' = ' +
                Inlist.parse_input(datum.name, datum.value, datum.type) + "\n"
    end
  end

  # Marks a data category so that it can be staged into an inlist
  def flagged
    @data_hash.keys.select { |key| @data_hash[key].flagged }
  end

  # Collects all data categories into a hash of arrays (each array is a
  # namelist) that is read whenever the inlist is converted to a string
  # (i.e. when it is printed to a file or the screen).
  def stage_flagged
    make_fresh_writelist # start from scratch

    flagged.each { |name| stage_namelist_command(name) } # stage each datum

    # blank lines between disparate data
    namelists.each do |namelist|
      @to_write[namelist].each_index do |i|
        next if [0, @to_write[namelist].size - 1].include? i
        this_line = @to_write[namelist][i]
        prev_line = @to_write[namelist][i - 1]

        this_line = '' if this_line.nil?
        prev_line = '' if prev_line.nil?
        if this_line.empty? && !(prev_line.empty? || prev_line == "\n")
          @to_write[namelist][i] = "\n"
        end
      end
    end
  end

  # Takes the staged data categories and formats them into a string series of
  # namelists that are MESA-readable.
  def to_s
    result = ''
    namelists.each do |namelist|
      result += "\n&#{namelist}\n"
      result += @to_write[namelist].join('')
      result += "\n/ ! end of #{namelist} namelist\n"
    end
    result.sub("\n\n\n", "\n\n")
  end
end

class NamelistError < Exception; end
