Gem::Specification.new do |s|
  s.name = 'mesa_script'
  s.version = '0.2.1'
  s.authors = ['William Wolf']
  s.date = '2023-04-18'
  s.description = 'MesaScript - a DSL for making dynamic inlists for the MESA '\
                  'stellar evolution code.'
  s.summary = <<-LONGDESC
    MesaScript is a domain specific language (DSL) that allows the user to write
    inlists for MESA that include variables, loops, conditionals, etc. For more
    detailed instructions, see the readme on the github page at

    https://github.com/wmwolf/MesaScript

    This software requires a relatively modern installation of MESA (version >
    5596). It has been tested on Ruby versions > 1.9 and up to 3.2, but there is
    no guarantee it will work on older (or newer!) versions. Any bugs or
    requests should be reported to the github repository.
  LONGDESC
  s.email = 'wolfwm@uwec.edu'
  s.files = ['README.md', 'lib/mesa_script.rb']
  s.homepage = 'https://billwolf.space/MesaScript/'
  s.has_rdoc = false
  s.bindir = 'bin'
  s.executables = ['inlist2mesascript']
  s.licenses = ['MIT']
end
