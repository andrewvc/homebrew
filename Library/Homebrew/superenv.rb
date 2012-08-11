require 'extend/ENV'

def superenv_bin
  @bin ||= (HOMEBREW_REPOSITORY/"Library/x").children.reject{|d| d.basename.to_s > MacOS::Xcode.version }.max
end

def superenv?
  superenv_bin.directory? and not ARGV.include? "--lame-env"
end

class << ENV
  def reset
    %w{CC CXX LD CPP OBJC CFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS LDFLAGS CPPFLAGS 
      MAKEFLAGS SDKROOT CMAKE_PREFIX_PATH CMAKE_FRAMEWORK_PATH MAKE MAKEJOBS}.
      each{ |x| delete(x) }
    delete('CDPATH') # avoid make issues that depend on changing directories
    delete('GREP_OPTIONS') # can break CMake
    delete('CLICOLOR_FORCE') # autotools doesn't like this

    if MacOS.mountain_lion?
      # Fix issue with sed barfing on unicode characters on Mountain Lion
      delete('LC_ALL')
      ENV['LC_CTYPE'] = "C"
    end
  end

  def setup_build_environment
    reset

    ENV['CC'] = determine_cc
    ENV['CXX'] = determine_cxx
    ENV['LD'] = 'ld'
    ENV['CPP'] = 'cpp'
    ENV['MAKE'] = 'make'
    ENV['MAKEFLAGS'] ||= "-j#{Hardware.processor_count}"
    ENV['PATH'] = determine_path
    ENV['CMAKE_PREFIX_PATH'] = determine_cmake_prefix_path
    ENV['PKG_CONFIG_PATH'] = determine_pkg_config_path

    macosxsdk(MacOS.version)
  end

  def macosxsdk version
    #TODO simplify
    delete('MACOSX_DEPLOYMENT_TARGET')
    delete('CMAKE_FRAMEWORK_PATH')

    ENV['MACOSX_DEPLOYMENT_TARGET'] = version.to_s if version == MacOS.version

    if not MacOS::CLT.installed?
      remove 'CMAKE_PREFIX_PATH', ENV['SDKROOT']
      ENV['SDKROOT'] = MacOS.sdk_path(version.to_s)
      ENV['CMAKE_FRAMEWORK_PATH'] = "#{ENV['SDKROOT']}/System/Library/Frameworks"
      prepend_path 'CMAKE_PREFIX_PATH', "#{ENV['SDKROOT']}/usr"
    else
      ENV['CMAKE_PREFIX_PATH'] = HOMEBREW_PREFIX.to_s
    end
  end

  def universal_binary
    ENV['HOMEBREW_UNIVERSAL'] = "1"
  end

### DEPRECATED or BROKEN
  def m64; end # no longer supported
  def m32; end # no longer supported
  def gcc_4_0_1; end # no longer supported
  def fast; end # no longer supported
  def O4; end # no longer supported
  def O3; end # no longer supported
  def O2; end # no longer supported
  def Os; end # no longer supported
  def Og; end # no longer supported
  def O1; end # no longer supported
  def libxml2; end # added automatically
  def x11; end # added automatically
  def minimal_optimization; end # no longer supported
  def no_optimization; end # no longer supported
  def enable_warnings; end # no longer supported
  def fortran; end # We only support Xcode 4.3+ with superenv so no Apple fortran

### DEPRECATE THESE
  def compiler
    case ENV['CC']
      when "llvm-gcc" then :llvm
      when "gcc" then :gcc
    else
      :clang
    end
  end
  def deparallelize
    delete('MAKEFLAGS')
  end
  alias_method :j1, :deparallelize
  def gcc
    ENV['CC'] = "gcc"
    ENV['CXX'] = "g++"
  end
  def llvm
    ENV['CC'] = "llvm-gcc"
    ENV['CXX'] = "llvm-g++"
  end
  def clang
    ENV['CC'] = "clang"
    ENV['CXX'] = "clang++"
  end

  def make_jobs
    ENV['MAKEFLAGS'] =~ /-j(\d)+/
    [$1.to_i, 1].max
  end

  private

  def determine_path
    paths = ORIGINAL_PATHS.dup
    paths.delete(HOMEBREW_PREFIX/:bin)
    paths.unshift "/opt/X11/bin"
    paths.unshift("#{HOMEBREW_PREFIX}/bin")
    if not MacOS::CLT.installed?
      xcpath = `xcode-select -print-path`.chomp #TODO future-proofed
      paths.unshift("#{xcpath}/usr/bin")
      paths.unshift("#{xcpath}/Toolchains/XcodeDefault.xctoolchain/usr/bin")
    end
    paths.unshift(superenv_bin)
    paths.to_path_s
  end

  def determine_cc
    if ARGV.include? '--use-gcc'
      "gcc"
    elsif ARGV.include? '--use-llvm'
      "llvm-gcc"
    elsif ARGV.include? '--use-clang'
      "clang"
    elsif ENV['HOMEBREW_USE_CLANG']
      opoo %{HOMEBREW_USE_CLANG is deprecated, use HOMEBREW_CC="clang" instead}
      "clang"
    elsif ENV['HOMEBREW_USE_LLVM']
      opoo %{HOMEBREW_USE_LLVM is deprecated, use HOMEBREW_CC="llvm" instead}
      "llvm-gcc"
    elsif ENV['HOMEBREW_USE_GCC']
      opoo %{HOMEBREW_USE_GCC is deprecated, use HOMEBREW_CC="gcc" instead}
      "gcc"
    elsif ENV['HOMEBREW_CC']
      if %w{clang gcc llvm}.include? ENV['HOMEBREW_CC']
        ENV['HOMEBREW_CC']
      else
        opoo "Invalid value for HOMEBREW_CC: #{ENV['HOMEBREW_CC']}"
        "cc"
      end
    else
      "cc"
    end
  end

  def determine_cxx
    case ENV['CC']
      when "clang" then "clang++"
      when "llvm-gcc" then "llvm-g++"
      when "gcc" then "gcc++"
    else
      "c++"
    end
  end

  def determine_pkg_config_path
    paths = %W{#{MacOS::X11.lib}/pkgconfig #{MacOS::X11.share}/pkgconfig}
    if MacOS.mountain_lion?
      # Mountain Lion no longer ships some .pcs; ensure we pick up our versions
      paths << "#{HOMEBREW_REPOSITORY}/Library/Homebrew/pkgconfig"
    end
    paths.to_path_s
  end

  def determine_cmake_prefix_path
    [HOMEBREW_PREFIX, MacOS::X11.prefix].to_path_s
  end

end if superenv?


if not superenv?
  ENV.extend(HomebrewEnvExtension)
  # we must do this or tools like pkg-config won't get found by configure scripts etc.
  ENV.prepend 'PATH', "#{HOMEBREW_PREFIX}/bin", ':' unless ORIGINAL_PATHS.include? HOMEBREW_PREFIX/'bin'
end


class Array
  def to_path_s
    map(&:to_s).select{|s| s and File.directory? s }.join(':')
  end
end
