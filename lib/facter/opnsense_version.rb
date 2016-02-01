if File.exist? '/conf/config.xml'

  Facter.add("opnsense") do
    confine :kernel => "FreeBSD"
    setcode do
      true
    end
  end

  if File.exist? '/usr/local/opnsense/version/opnsense'
    Facter.add(:opnsense_version) do
      confine :kernel => "FreeBSD"
      setcode do
        #Facter::Core::Execution.exec("/usr/sbin/pkg query %n-%v opnsense opnsense-devel | /usr/bin/grep -m 1 -oE '[0-9._]+'")
        version = File.read('/usr/local/opnsense/version/opnsense')
        version.chomp
      end
    end
  end

else

  Facter.add("opnsense") do
    confine :kernel => "FreeBSD"
    setcode do
      false
    end
  end

end
