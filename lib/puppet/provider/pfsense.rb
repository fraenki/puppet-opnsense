require 'base64'
require 'fileutils'
require 'rexml/document'

class Puppet::Provider::Pfsense < Puppet::Provider
  desc "pfSense common"

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

  def read_config()
    return REXML::Document.new File.read('/cf/conf/config.xml')
  end

  def lock_config
    f = File.open('/tmp/config.lock', File::RDWR|File::CREAT, 0666)
    if !f.flock(File::LOCK_NB|File::LOCK_EX)
      f.close
      fail "Unable to get exclusive lock on pfSense configuration"
    end
    f.close
    Puppet.debug "Set LOCK_EX on pfSense configuration"
  end

  def write_config(config)
    fail "Expected an REXML::Document but got \'#{config.class.name}\' instead" if config.class.name != 'REXML::Document'
    # New config revision
    xmldoc = set_revision(config)
    # Prettify
    xmldoc << REXML::XMLDecl.new(version=1.0)
    formatter = REXML::Formatters::Pretty.new
    formatter.width = 10000
    formatter.compact = true
    formatter.write(xmldoc.root, _xmldoc = "")
    File.open('/cf/conf/config.xml', 'w') do |file|
      file.write(_xmldoc)
    end
    Puppet.debug "Changes to pfSense configuration written to disk"
    # Clear config cache to make changes visible in pfSense GUI
    clear_cache
    return true
  end

  def clear_cache
    file = '/tmp/config.cache'
    if File.file?(file)
      Puppet.debug "Deleting pfSense config cache"
      File.delete(file)
    end
  end

  def unlock_config
    f = File.open('/tmp/config.lock', File::RDWR|File::CREAT, 0666)
    if !f.flock(File::LOCK_UN)
      f.close
      fail "Unable to remove exclusive lock on pfSense configuration"
    end
    Puppet.debug "Set LOCK_UN on pfSense configuration"
    f.close
  end

  def set_revision(xmldoc)
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

    if REXML::XPath.first(xmldoc, "//pfsense/revision")
      _pfsense = REXML::XPath.first(xmldoc, "//pfsense")
      _pfsense.delete_element("revision")
      Puppet.debug "Deleted old revision from pfSense configuration"
    end

    xmldoc.elements["pfsense"].add_element _revision
    return xmldoc
  end

end
