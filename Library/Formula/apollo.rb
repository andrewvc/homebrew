require 'formula'

class BerkeleyDbJe < Formula
  homepage 'http://www.oracle.com/technetwork/database/berkeleydb/overview/index-093405.html'
  url "http://download.oracle.com/maven/com/sleepycat/je/5.0.34/je-5.0.34.jar"
  version '5.0.34'
  md5 '09fa2cb8431bb4ca5a0a0f83d3d57ed0'
end

class FuseMQApolloMQTT < Formula
  homepage 'https://github.com/fusesource/fuse-extra/tree/master/fusemq-apollo/fusemq-apollo-mqtt'
  url "http://repo.fusesource.com/nexus/content/repositories/public/org/fusesource/fuse-extra/fusemq-apollo-mqtt/1.3/fusemq-apollo-mqtt-1.3-uber.jar"
  version '1.3'
  md5 'f33e56ddc2e302eda10fc4bb16f2d165'
end

class Apollo < Formula
  homepage 'http://activemq.apache.org/apollo'
  url "http://archive.apache.org/dist/activemq/activemq-apollo/1.4/apache-apollo-1.4-unix-distro.tar.gz"
  version "1.4"
  md5 '2581e361670e52d9016edc113de53e6c'

  option "no-bdb", "Install without bdb store support."
  option "no-mqtt", "Install without MQTT protocol support."

  def install
    prefix.install %w{ LICENSE NOTICE readme.html docs examples }
    libexec.install Dir['*']

    unless build.include? "no-bdb"
      BerkeleyDbJe.new.brew do
        (libexec+"lib").install Dir['*.jar']
      end
    end

    unless build.include? "no-mqtt"
      FuseMQApolloMQTT.new.brew do
        (libexec+"lib").install Dir['*.jar']
      end
    end

    (bin+'apollo').write <<-EOS.undent
      #!/bin/bash
      exec "#{libexec}/bin/#{name}" "$@"
    EOS

    plist_path.write startup_plist
    plist_path.chmod 0644
  end

  def caveats
    tod  = "~/Library/LaunchAgents"
    to = "#{tod}/#{plist_name}"
    from = "#{opt_prefix}/#{plist_name}"

    <<-EOS.undent
    To create the broker:
        apollo create #{var}/apollo

    If this is your first install, automatically load on login with:
        mkdir -p #{tod}
        ln -s #{from} #{tod}
        launchctl load -w #{to}

    If you just upgraded and #{name} is already loaded:
        launchctl unload -w #{to}
        launchctl load -w #{to}

    Or to start the broker in the foreground run:
        #{var}/apollo/bin/apollo-broker run
    EOS
  end

  def startup_plist; <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>KeepAlive</key>
    <true/>
    <key>Label</key>
    <string>#{plist_name}</string>
    <key>ProgramArguments</key>
    <array>
      <string>#{var}/apollo/bin/apollo-broker</string>
      <string>run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>UserName</key>
    <string>#{`whoami`.chomp}</string>
    <key>WorkingDirectory</key>
    <string>#{var}/apollo</string>
  </dict>
</plist>
EOS
  end

end
