Gem::Specification.new do |s|
  s.name = 'mesa_script'
  s.version = '0.1.9'
  s.authors = ['William Wolf']
  s.date = '2018-08-14'
  s.description = 'MesaScript - a DSL for making dynamic inlists for the MESA '\
                  'stellar evolution code.'
  s.summary = <<-LONGDESC
    MesaScript is a domain specific language (DSL) that allows the user to write
    inlists for MESA that include variables, loops, conditionals, etc. For more
    detailed instructions, see the readme on the github page at

    https://github.com/wmwolf/MesaScript

    This software requires a relatively modern installation of MESA (version >
    5596). It has been tested on Ruby versions > 1.9, but there is no guarantee
    it will work on older (or newer!) versions. Any bugs or requests should be
    sent to the author, Bill Wolf, at wmwolf@physics.ucsb.edu.
  LONGDESC
  s.email = 'wmwolf@asu.edu'
  s.files = ['README.md', 'lib/mesa_script.rb']
  s.homepage = 'https://wmwolf.github.io'
  s.has_rdoc = false
  s.bindir = 'bin'
  s.executables = ['inlist2mesascript']
  s.licenses = ['MIT']
end
