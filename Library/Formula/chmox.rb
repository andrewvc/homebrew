require 'formula'

class Chmox < Formula
  head 'cvs://:pserver:anonymous@chmox.cvs.sourceforge.net:/cvsroot/chmox:Sources'
  homepage 'http://chmox.sourceforge.net'

  def install
    system "xcodebuild SYMROOT=build"
    prefix.install "build/Default/Chmox.app"
  end

  def caveats; <<-EOS.undent
    Installed:
        #{opt_prefix}/Chmox.app
    Use \"brew linkapps\" to symlink into ~/Applications.
    EOS
  end
end
