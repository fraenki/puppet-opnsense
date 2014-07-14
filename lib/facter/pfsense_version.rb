if File.exist? '/cf/conf/config.xml'

  Facter.add("pfsense") do
    confine :kernel => "FreeBSD"
    setcode do
      true
    end
  end

  if File.exist? '/etc/version'
    Facter.add(:pfsense_version) do
      confine :kernel => "FreeBSD"
      setcode do
        version = File.read('/etc/version')
        version.chomp
      end
    end
  end

  if File.exist? '/etc/version_base'
    Facter.add(:pfsense_version_base) do
      confine :kernel => "FreeBSD"
      setcode do
        version = File.read('/etc/version_base')
        version.chomp
      end
    end
  end

  if File.exist? '/etc/version_kernel'
    Facter.add(:pfsense_version_kernel) do
      confine :kernel => "FreeBSD"
      setcode do
        version = File.read('/etc/version_kernel')
        version.chomp
      end
    end
  end

else

  Facter.add("pfsense") do
    confine :kernel => "FreeBSD"
    setcode do
      false
    end
  end

end
