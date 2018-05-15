require_relative 'mesa_script/lib/mesa_script'

# This script produces three inlists, named inlist_1, inlist_2, and inlist_3.
# Each has a different value for the "mass" variable (in the code block below)
# Each has different values for initial_mass and saved_model_name, as well as a
# different LOGS directory name. Try running ('ruby mesa_test.rb') this and then
# seeing if you understand how the output relates to the input.

# customizing what namelists are in use
# Inlist.add_star_defaults # adds star_job, controls, and pgstar
# Inlist.add_star_job_defaults # just load star_job data
# Inlist.add_controls_defaults # just load controls data
# Inlist.add_pgstar_defaults   # just load pgstar data
# Inlist.add_binary_defaults   # just add binary_controls datad
# Inlist.delete_namelist('controls') # remove controls data

masses = [1, 2, 3]
masses.each do |mass|
  Inlist.make_inlist('inlist_' + mass.to_s) do
    # Can set variables here. Really, any simple ruby should be fine here
    log_title = 'LOGS_' + mass.to_s
    log_directory log_title

    # Ordering of commands is irrelevant. Commands are automatically corralled
    # into their proper namelists and then ordered according to the defaults
    # file from which they were found. Consecutive items in the defaults
    # file will not have line breaks between them, but unconsecutive items
    # will have a line break to keep different chunks of a inlist commands
    # separate.
    mass_change 1e-7
    load_saved_model true
    saved_model_name "test_#{mass}.mod"

    # Inlist methods are case-insensitive (in that lower-case is ALWAYS ok)
    # That is, method names can be invoked as they appear in the .inc or
    # files in star/private/star_controls.inc, for example, or they can be
    # invoked in all lower case. Other "spellings" will fail.
    relax_y true

    # No argument? no problem. The default is selected.
    use_ledoux_criterion

    # Can use variables in assignments. Non-strings will be converted from ruby
    # to fortran, where needed, and if the value you pass in has the wrong type,
    # an error will be thrown at runtime, telling you where the parsing error is
    initial_mass mass

    # Using a string argument for something that isn't expecting a string will
    # **NOT** thrown an error. Instead, the string is interpreted literally and
    # inserted into the inlist. This is meant to be a failsafe for if/when
    # something else is broken in MesaScript.
    mass_change '1.0d-9'

    # Yep, pgstar is in the mix by default, too.
    kipp_win_flag true
    grid1_win_flag true

    # Array assignments work a bit differently (note the SQUARE BRACKETS):
    xa_central_lower_limit_species[1] = 'h1'
    xa_central_lower_limit[1] = 1e-3

    # Using a command more than once overwrites the first instance. Also note
    # the alternate syntaxes for array assignments here.
    xa_central_lower_limit_species(1, 'he4')
    xa_central_lower_limit 1, 1e-2
  end
end
