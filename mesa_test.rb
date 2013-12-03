require './mesa_script'

masses = [1,2,3]
masses.each do |mass|
  Inlist.make_inlist('inlist_' + mass.to_s) {
  
    # Can set variables here. Really, any simple ruby should be fine here
    my_mass = mass
    log_directory "LOGS_#{mass.to_s}"

    # Ordering of commands is irrelevant. Commands are automatically corralled
    # into their proper namelists and then ordered according to the defaults file
    # from which they were found
    mass_change = 1e-7
  
    # Inlist methods are case-insensitive (in that lower-case is ALWAYS ok)
    relax_y true
  
    # No argument? no problem. The default is selected.
    new_y
  
    # Can use variables in assignments. Non-strings will be converted by ruby,
    # but currently things like '.true.' just can't be done (should be an easy
    # fix). Methods technically know about the expected argument type, but this 
    # info isn't used yet.
    initial_mass my_mass
  
    kipp_win_flag true
    grid1_win_flag true
  
    # No write-out functionality yet, but would be really easy to implement.
    puts self
   
  }
end
