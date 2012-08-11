#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby

# This script is called by formula_installer as a separate instance.
# Rationale: Formula can use __END__, Formula can change ENV
# Thrown exceptions are propogated back to the parent process over a pipe

require 'global'

at_exit do
  # the whole of everything must be run in at_exit because the formula has to
  # be the run script as __END__ must work for *that* formula.

  error_pipe = nil

  begin
    raise $! if $! # an exception was already thrown when parsing the formula

    require 'hardware'
    require 'keg'
    require 'superenv'

    ENV.setup_build_environment

    # Force any future invocations of sudo to require the user's password to be
    # re-entered. This is in-case any build script call sudo. Certainly this is
    # can be inconvenient for the user. But we need to be safe.
    system "/usr/bin/sudo -k"

    # The main Homebrew process expects to eventually see EOF on the error
    # pipe in FormulaInstaller#build. However, if any child process fails to
    # terminate (i.e, fails to close the descriptor), this won't happen, and
    # the installer will hang. Set close-on-exec to prevent this.
    # Whether it is *wise* to launch daemons from formulae is a separate
    # question altogether.
    if ENV['HOMEBREW_ERROR_PIPE']
      require 'fcntl'
      error_pipe = IO.new(ENV['HOMEBREW_ERROR_PIPE'].to_i, 'w')
      error_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    end

    install(Formula.factory($0))
  rescue Exception => e
    unless error_pipe.nil?
      Marshal.dump(e, error_pipe)
      error_pipe.close
      exit! 1
    else
      onoe e
      puts e.backtrace
      exit! 2
    end
  end
end

def install f
  f.requirements.each { |dep| dep.modify_build_environment }

  f.recursive_deps.uniq.each do |dep|
    dep = Formula.factory dep
    if dep.keg_only?
      opt = HOMEBREW_PREFIX/:opt/dep.name

      raise "#{opt} not present\nReinstall #{dep}. Sorry :(" unless opt.directory?

      ENV.prepend_path 'PATH', "#{opt}/bin"
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{opt}/lib/pkgconfig"
      ENV.prepend_path 'PKG_CONFIG_PATH', "#{opt}/share/pkgconfig"
      ENV.prepend_path 'CMAKE_PREFIX_PATH', opt

      if superenv?
        ENV.prepend 'HOMEBREW_DEP_PREFIXES', dep.name
      else
        ENV.prepend 'LDFLAGS', "-L#{opt}/lib" if (opt/:lib).directory?
        ENV.prepend 'CPPFLAGS', "-I#{opt}/include" if (opt/:include).directory?
        ENV.prepend_path 'ACLOCAL_PATH', "#{opt}/share/aclocal"
      end
    end
  end

  if f.fails_with? ENV.compiler
    cs = CompilerSelector.new f
    cs.select_compiler
    cs.advise
  end

  f.brew do
    if ARGV.flag? '--git'
      system "git init"
      system "git add -A"
    end
    if ARGV.flag? '--interactive'
      ohai "Entering interactive mode"
      puts "Type `exit' to return and finalize the installation"
      puts "Install to this prefix: #{f.prefix}"

      if ARGV.flag? '--git'
        puts "This directory is now a git repo. Make your changes and then use:"
        puts "  git diff | pbcopy"
        puts "to copy the diff to the clipboard."
      end

      interactive_shell f
      nil
    else
      f.prefix.mkpath
      f.install
      FORMULA_META_FILES.each do |filename|
        next if File.directory? filename
        target_file = filename
        target_file = "#{filename}.txt" if File.exists? "#{filename}.txt"
        # Some software symlinks these files (see help2man.rb)
        target_file = Pathname.new(target_file).resolved_path
        f.prefix.install target_file => filename rescue nil
        (f.prefix+file).chmod 0644 rescue nil
      end
    end
  end
end
