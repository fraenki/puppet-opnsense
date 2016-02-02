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

    Facter.add(:opnsense_major) do
      confine :kernel => "FreeBSD"
      setcode do
        Facter.value(:opnsense_version).split('.')[0]
      end
    end

    Facter.add(:opnsense_minor) do
      confine :kernel => "FreeBSD"
      setcode do
        Facter.value(:opnsense_version).split('.')[1]
      end
    end

    Facter.add(:opnsense_patchlevel) do
      confine :kernel => "FreeBSD"
      setcode do
        Facter.value(:opnsense_version).split('.')[2].split('-')[0]
      end
    end

    Facter.add(:opnsense_revision) do
      confine :kernel => "FreeBSD"
      setcode do
        Facter.value(:opnsense_version).split('.')[2].split('-')[1]
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
