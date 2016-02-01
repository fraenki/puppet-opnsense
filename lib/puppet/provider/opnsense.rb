require 'base64'
require 'fileutils'
require 'rexml/document'

class Puppet::Provider::Opnsense < Puppet::Provider
  desc "OPNsense common"

  def exists?
    @property_hash[:ensure] == :present
  end

  # Cache or "prefetch" the state of all *managed* resource instances
  def self.prefetch(resources)
    users = instances
    resources.keys.each do |name|
      if provider = users.find{ |usr| usr.name == name }
        resources[name].provider = provider
      end
    end
  end

  def self.read_config
    return REXML::Document.new File.read('/conf/config.xml')
  end

  def self.lock_config
    f = File.open('/tmp/config.lock', File::RDWR|File::CREAT, 0666)
    if !f.flock(File::LOCK_NB|File::LOCK_EX)
      f.close
      fail "Unable to get exclusive lock on OPNsense configuration"
    end
    f.close
    Puppet.debug "Set LOCK_EX on OPNsense configuration"
  end

  def self.write_config(config)
    fail "Expected an REXML::Document but got \'#{config.class.name}\' instead" if config.class.name != 'REXML::Document'
    # New config revision
    xmldoc = set_revision(config)
    # Prettify
    xmldoc << REXML::XMLDecl.new(version=1.0)
    formatter = REXML::Formatters::Pretty.new
    formatter.width = 10000
    formatter.compact = true
    formatter.write(xmldoc.root, _xmldoc = "")
    File.open('/conf/config.xml', 'w') do |file|
      file.write(_xmldoc)
    end
    Puppet.debug "Changes to OPNsense configuration written to disk"
    # Clear config cache to make changes visible in OPNsense GUI
    clear_cache
    return true
  end

  def self.clear_cache
    file = '/tmp/config.cache'
    if File.file?(file)
      Puppet.debug "Deleting OPNsense config cache"
      File.delete(file)
    end
  end

  def self.unlock_config
    f = File.open('/tmp/config.lock', File::RDWR|File::CREAT, 0666)
    if !f.flock(File::LOCK_UN)
      f.close
      fail "Unable to remove exclusive lock on OPNsense configuration"
    end
    Puppet.debug "Set LOCK_UN on OPNsense configuration"
    f.close
  end

  def self.set_revision(xmldoc)
    fail "Expected an REXML::Document but got \'#{xmldoc.class.name}\' instead" if xmldoc.class.name != 'REXML::Document'
    _revision = REXML::Element.new 'revision'
    _time     = REXML::Element.new 'time'
    _descr    = REXML::Element.new 'description'
    _user     = REXML::Element.new 'username'
    _time.text  = Time.now.to_i
    _descr.text = REXML::CData.new("admin@#{Facter.value(:ipaddress)}: puppet made unknown change")
    _user.text  = "admin@#{Facter.value(:ipaddress)}"
    _revision.add_element _time
    _revision.add_element _descr
    _revision.add_element _user

    if REXML::XPath.first(xmldoc, "//opnsense/revision")
      _opnsense = REXML::XPath.first(xmldoc, "//opnsense")
      _opnsense.delete_element("revision")
      Puppet.debug "Deleted old revision from OPNsense configuration"
    end

    xmldoc.elements["opnsense"].add_element _revision
    return xmldoc
  end

end
