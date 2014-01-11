MesaScript
==========

###The Short Short Version
To get up and running fast, skip to installation, then try and use the included
sample file, `sample.rb` (via running `ruby sample.rb` in the command line). The
comments in `sample.rb` should get you started, especially if you have at least
a little Ruby know-how.
###What is MesaScript?
Lightweight, Ruby-based language that provides a powerful way to make inlists
for MESA projects. Really, MesaScript is a DSL (domain-specific language) built
on top of Ruby, so Ruby code "just works" inside MesaScript (if you're familiar
with it, think of what SASS is to CSS, but on a smaller scale).

### What does MesaScript do?
MesaScript provides a way to build inlists for use with
[MESA](http://mesa.sourceforge.net) using Ruby, though you need not know much 
at all about Ruby to use it. The main point is that you can use
variables when creating an inlist, making a reusable template for parameter
space studies when only a few inlist commands vary between a large number of
inlists. Most, if not all, of what MesaScript does can be done by using MESA's
`run_star_extras` hooks, but for the purposes of documenting what I do with
MESA, I find inlists more enlightening, and I try to stick to high-level
languages whenever I can.

There are other benefits, too. MesaScript automatically checks your input to
make sure that the types of arguments you give for various namelist items match
what is expected, and the resulting inlist is neatly formatted and sensibly
ordered. You can also easily convert an existing inlist to MesaScript for
editing and further generalization. In general, *writing an inlist in*
*MesaScript is no more difficult than writing a normal inlist, but you have far*
*more flexibility*. So why not give it a try?

If you know a little Ruby (want to learn? 
[Try Ruby here!](http://tryruby.org/levels/1/challenges/0)), the possibilities
are pretty wide open. You could easily make a script that starts with a given
set of parameters, run MESA star, then use the output of that run to dictate a
new inlist and run, creating a chain (maybe a MESA root find of sorts).

###Installation
Someday, I hope to package this as a gem, but for now, it's staying hosted on 
Github, which means you need to install it yourself. Clone or otherwise
download the repository somewhere to your home directory with

    git clone https://github.com/wmwolf/MesaScript.git ~/MesaScript
	  
or somewhere else to your liking.

Then, either copy the file `mesa_script.rb` to somewhere along Ruby's path, or
set up another stand-in file that points to your `mesa_script.rb` file in
Ruby's path. To find Ruby's path, type

    ruby -e 'puts $:'
	  
in your terminal. If Ruby is properly configured, as it is on most modern Unix
systems, you should see a list of possible directories. Either copy
`mesa_script.rb` there or do what I do and make a new file called
`mesa_script.rb` there and have it just be

    require '/PATH/TO/YOUR/CLONED/REPOSITORY/mesa_script.rb'
	  
This way, if you later update your repo via `git pull`, you won't need to copy
`mesa_script.rb` again. Also, if you'd like to use the included (optional)
`inlist2mesascript` tool, copy that to somewhere along you system's path (
`echo $PATH`). Then type `inlist2mesascript -h` to learn more about that tool.
As you
might guess, it takes an existing MESA inlist and converts it to a file in
MesaScript that, if executed by Ruby should produce essentially the same inlist
(good for moving a project to MesaScript).

To check if Ruby can see the file, try doing `ruby -e 'require "mesa_script"'`.
If no error occurs, it is working fine.

Finally, you must have your `MESA_DIR` environment variable set for anything to
work. The `mesa_script.rb` file generates all the necessary data it needs from
the MESA source on the fly (this also makes it nearly MESA version
independent).

###Basic Usage
The `mesa_script.rb` file defines just one class, Inlist, which we'll interact
with primarily through one class method, `make_inlist`. Just put the following
in a file to make a blank inlist:

    require 'mesa_script'
    
    Inlist.make_inlist('babys_first_inlist') {
      # inlist commands go here
    }
    
This creates a file called `babys_first_inlist` that will be pretty
boring. It will create three namelists (the usual `star_job`, `controls`, and
`pgstar`) and leaves them blank inside, which is a perfectly acceptable inlist
for MESA to use, since it has defaults available. Now let's say you put this in
a file called `my_first_mesascript.rb` (`.rb` is the extension for Ruby files,
by the way). Then to actually generate the inlist, enter
`ruby my_first_mesascript.rb` at the command line and watch in awe as
`babys_first_inlist` pops into existence. You've created an inlist using
MesaScript, and you did so using fewer lines than it would have taken to
actually make that inlist on your own (technically)!

###Entering Inlist Commands
Making blank inlists is boring, so now let's cover how you actually make useful
inlists. For mesa inlists, there are really only two types of declarations:
those for scalars and those for array. Let's talk about scalars first, since
they are far more common. Then we'll get to the more complicated array
assignments.

####Scalar Assignments
As an example, let's say we want to set the initial mass of our star to 2.0
solar masses. The inlist command for this is `initial_mass`. In a regular
inlist file, we would need to put this in the proper namelist, `&controls` as
`initial_mass = 2.0`. In MesaScript, there are two ways to do this:

    initial_mass 2.0    # this
    initial_mass(2.0)   # is the same as this
    
In Ruby, parentheses are optional for method calls, so either way is
acceptable. Note that unlike in normal inlists, MesaScript doesn't care about
the namelist this attribute belongs to. It'll figure it out on its own and
place it appropriately.

**WARNING**: You *cannot* use the standard inlist notation of

    initial_mass = 2.0  # DON'T EVER DO THIS EVER EVER EVER
    
it will *not* throw an error, because it will simply set a new Ruby variable
called `initial_mass`. (For the person curious as to why I didn't program this
functionality in, google something like "instance_eval setter method" to
discover what took me too long to figure out.)

####Array Assignments
As an example, let's say we want to set a lower limit on a certain central 
abundance as a stopping condition. Then we would, at the minimum, need to set 
the inlist command `xa_central_lower_limit_species(1) = 'h1'`, for example. In MesaScript, there are three ways to do this:

    xa_central_lower_limit_species[1] = 'h1'    # These are
    xa_central_lower_limit_species(1, 'h1')     # all the
    xa_central_lower_limit_species 1, 'h1'      # same

**WARNING**: Again, the standard inlist notation for array assignment will not
work:

    xa_central_lower_limit_species(1) = 'h1'    # THIS ENDS IN SADNESS
    
I tried to program this functionality in, and the kind people at 
[StackOverflow](http://stackoverflow.com/questions/21036873/how-do-i-write-a-method-to-edit-an-array-hash-using-parentheses-instead-of-squar/21044781?noredirect=1#21044781) kindly but firmly convinced me it was utterly impossible to to with Ruby without writing a parser of my own. Just stick to the bracket syntax or the less natural parentheses/space notations.

####Other Details
That's really all you need to know to start making inlists with MesaScript,
though I should remind you, especially if you aren't familiar with Ruby, about
the basic types of entries you might use. Most inlist commands are one of the
following: booleans, strings, floats, or integers. 

**Booleans** in Ruby are `true` and `false` (case matters, and no periods). 

**Strings** work the same as in fortran, though
single quotes are more "literal" than double quotes. Double quotes allow for
escaped characters and string interpolation using the `#{...}` notation, which
might be useful. For instance,

    my_mass = 2.0
    initial_mass = my_mass
    save_model true
    save_model_filename "my_star_#{my_mass}.mod"

will produce (among other things) the line 
`save_model_filename = 'my_star_2.0.mod'` in the resulting inlist. Note also the
utility of having the initial mass and the save file name being dependent on a
single variable.

**Integers** are just
integers (I don't know of a useful literal other than just typing out the
entire number, though you can use underscores to make it clearer, e.g.
`100_000_000` is the same as `100000000` in Ruby).

**Floats** use an "e", and never a "d" for an exponential indicator, e.g.
`6.02e23`. Ruby floats have arbitrary precision, so there are no doubles.

Finally, if a particular command is giving you trouble, you can always just encase what you *want* it to be (i.e. in Fortran lingo) in quotes (obviously this does nothing useful if MesaScript is expecting a string). For example

    mass_change 1e-7

will have the same effect as

    mass_change '1d-7'
    
since MesaScript will not try to parse `'1d-7'`. It was expecting a float, but
since it got a string, it assumes you know better than it.

A useful tidbit is that methods are case sensitive to a point. They have the
same "spelling" as what is found in the `.inc` file (like
`star/private/star_controls.inc`), but every method has an aliased method that
is the same, but all in lower case, so you don't need to remember the
capitalization so long as you remember the actual spelling.

Any Ruby inside the `make_inlist` block will be executed normally, and it can
see variables named outside of the block. So if you have some basic parameters
that can determine a large number of inlist commands, you can simply name those
parameters as variables at the top of your MesaScript file and then make the
actual MesaScript code weave them into your inlist appropriately. This way, the
actual parameter changing from inlist to inlist is taken outside of the actual
inlist commands so you don't forget to change a particular command when you
move on to a different run (like forgetting to change a `LOG_dir`, which I've
done a few too many times and thus overwriten some data).

###Deeper and Deeper...
Are you still reading this? Well, you must want to do more. 

###Using Custom Namelists
You can also make MesaScript know about additional namelists (or forget about
the standard three). After requiring the `mesa_script` file, you can change the
namelists it cares about via the following commands (obviously subbing out any
string containing `'namelist1'` or `'namelist2'` with your own appropriate
strings):

    require 'mesa_script'

    Inlist.namelists = ['namelist1', 'namelist2'] # all namelists you want
    
    # Then indicate the name of the '.inc' files like star/private/star_controls.inc
    Inlist.nt_files  = {
      'namelist1' => 'namelist1_controls.inc',
      'namelist2' => 'namelist2_controls.inc'
    }
    # Then indicate the names of the '.defaults' files like those in star/defaults
    Inlist.d_files = {
      'namelist1' => 'namelist1.defaults,
      'namelist2' => 'namelist2.defaults
    }
    # Then specify the paths to the files
    Inlist.nt_paths ={
      'namelist1' => '/path/to/namelist1_controls.inc',
      'namelist2' => '/path/to/namelist2_controls.inc'
    }

That *should* set things up to work with custom namelists, so long as the 
`.inc` and `.defaults` files are formatted more or less the same as the "stock"
ones.

###Accessing Current Values and Displaying Default Values
Perhaps you want to display a default value in your inlist, but not actually
change it. Well, most of the assignment methods mentioned earlier
are also getter methods. I haven't mentioned how these methods actually work, so I'll do so now since you're still reading this manifesto.

These methods first flag the name of the data category for going into the
inlist. Then if a new value is supplied to them, it changes the value in the
`Inlist` object's internal hash. Then, when all the user-supplied code has been
executed, it gathers all the flagged data and formats it into
properly-formatted namelists, which it then prints out in sequence to the file
name provided by the user. One final note about these methods, they always
return the value associated with the inlist object (the new one if you assign
it, or the current/default value if you don't set one).

So if you want to access any scalar, just call its method without an argument. 
Not only does this return the default value, but it also flags the category for
inclusion in the inlist so

    save_this_value = initial_mass
    
will set `save_this_value` to `1.0` (the default value in `controls.defaults`)
unless you had already assigned another value, in which case that would be saved
instead. Additionally, `initial_mass = 1.0` will appear in the final inlist, 
even though we didn't give `initial_mass` a new value. In fact, we could just
have a line like

    initial_z
    
that neither uses the return value nor changes the stored value. This will just
flag `initial_z` for being put in the final inlist. Note that there is
currently no way to unflag an inlist item.

For arrays, things work like you might expect. Any time any one of the versions
of the array methods are called, that entire array category is staged for
inclusion in the inlist. For example, you could do any of the following:

    xa_central_lower_limit      # returns a hash of values
    xa_central_lower_limit[1]   # returns the value associated with 1 in the hash
    xa_central_lower_limit(1)   # same as above
    xa_central_lower_limit 1    # same as above
    
Note that these array methods, as indicated, point to hashes (not arrays) of
values. So `xa_central_lower_limit_species[1] = 'h1'` would return 
`{1 => 'h1'}`.

##Further Work
I warmly welcome bug reports, feature suggestions, and most all, pull requests!