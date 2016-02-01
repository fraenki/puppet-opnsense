require File.join(File.dirname(__FILE__), '..', 'opnsense')
require 'rexml/document'

Puppet::Type.type(:opnsense_group).provide(:opnsense_group, :parent => Puppet::Provider::Opnsense) do
  desc "Group management on OPNsense."

  commands :pw => 'pw'

  def create
    # Lock config
    Puppet::Provider::Opnsense.lock_config

    # Fail on system groups
    if !sysgroup(@resource[:name])
      Puppet.debug "Group #{@resource[:name]} did not match a system group"
    else
      fail "The groupname #{@resource['name']} is reserved by the system"
    end

    # Get next free gid
    newgid = next_gid
    @resource[:gid] = newgid
    Puppet.debug "Assigned GID #{newgid} to group #{@resource[:name]}"

    # Compose XML elements
    _group = REXML::Element.new 'group'
    _descr = REXML::Element.new 'descr'
    _name  = REXML::Element.new 'name'
    _gid   = REXML::Element.new 'gid'
    _descr.text = resource[:comment] ? REXML::CData.new(resource[:comment]) : REXML::CData.new('')
    _name.text  = resource[:name]
    _gid.text   = newgid
    _group.add_element _descr
    _group.add_element _name
    _group.add_element _gid

    # Add privs
    if defined?(@resource[:privileges]) and !@resource[:privileges].nil? and !@resource[:privileges].include?(:absent)
      @resource[:privileges].each do |priv|
        _priv = REXML::Element.new 'priv'
        _priv.text = priv
        _group.add_element _priv
      end
    end

    # Add group to system
    addcmd

    # Add group to xml configuration
    xmldoc = Puppet::Provider::Opnsense.read_config
    xmldoc.elements["opnsense/system"].add_element _group

    # nextgid++
    nextgid = newgid.to_i
    Puppet.debug "Set next GID to #{nextgid}"
    xmldoc.elements["opnsense/system/nextgid"].text = nextgid + 1

    # Write changes to disk
    Puppet::Provider::Opnsense.write_config(xmldoc) || fail("Failed to write config")

    # Unlock config
    Puppet::Provider::Opnsense.unlock_config

    @property_hash[:gid] = newgid
    @property_hash[:ensure] = :present
  end

  def destroy
    # Edit XML configuration
    xmldoc = Puppet::Provider::Opnsense.read_config
    if REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']")
      _system = REXML::XPath.first(xmldoc, "//opnsense/system")
      _system.delete_element("group[name='#{@resource[:name]}']")
      Puppet.debug "Deleted group '#{@resource[:name]}'"
      Puppet::Provider::Opnsense.write_config(xmldoc)
    end
    # Delete from system
    pw("groupdel", @resource[:name])
    @property_hash.clear
  end

  def comment
    @property_hash[:comment]
  end

  def comment=(value)
    # Change xml
    xmldoc = Puppet::Provider::Opnsense.read_config
    if REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']/descr")
      # Change value
      _comment  = REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']/descr")
      _comment.text = REXML::CData.new(value)
    else
      # Add comment
      _group = REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']")
      _comment = REXML::Element.new 'descr'
      _comment.text = REXML::CData.new(value)
      _group.add_element _comment
    end
    Puppet::Provider::Opnsense.write_config(xmldoc)
    @property_hash[:comment] = value
  end

  def privileges
    @property_hash[:privileges]
  end

  def privileges=(array)
    xmldoc = Puppet::Provider::Opnsense.read_config
    array = [] if array.include?(:absent)
    # Get current privs
    privs = []
    REXML::XPath.each(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']/priv"){ |p|
      privs << p.get_text.value
    }
    # Delete privs
    privs.each do |priv|
      _group = REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']")
      if !array.include?(priv)
        _group.delete_element("priv[.='#{priv}']")
        Puppet.debug "Deleted privilege '#{priv}' from group #{@resource[:name]}"
      end
    end
    # Add privs
    array.each do |value|
      if !REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']/priv[.='#{value}']")
        _group = REXML::XPath.first(xmldoc, "//opnsense/system/group[name='#{@resource[:name]}']")
        _priv  = REXML::Element.new 'priv'
        _priv.text = value
        _group.add_element _priv
        Puppet.debug "Added privilege '#{value}' to group #{@resource[:name]}"
      end
    end
    # Write changes to disk
    Puppet::Provider::Opnsense.write_config(xmldoc)
    @property_hash[:privileges] = array
  end

  def gid 
    @property_hash[:gid]
  end

  # *Discover* instances of this resource type (only *existing* resources on this system)
  def self.instances
    pfgroups = []

    xmldoc = REXML::Document.new File.read('/conf/config.xml')

    xmldoc.elements.each("opnsense/system/group"){ |e|
      if defined? e.elements["descr"].get_text and defined? e.elements["descr"].get_text.value
        _comment = e.elements["descr"].get_text.value
      end
      if defined? e.elements["priv"].get_text and defined? e.elements["priv"].get_text.value
        _privileges = []
        e.elements.each("priv"){ |p|
          _privileges << p.get_text.value
        }
      end
      # Initialize @property_hash
      opngroups << new({ 
        :name           => e.elements["name"].get_text.value,
        :ensure         => :present,
        :comment        => _comment.nil? ? nil : _comment,
        :privileges     => _privileges.nil? ? [:absent] : _privileges,
        :gid            => e.elements["gid"].get_text.value,
      })
    }
    opngroups
  end

  def next_gid
    xmldoc = Puppet::Provider::Opnsense.read_config
    xmldoc.elements["opnsense/system/nextgid"].get_text.value || fail("Failed to query next GID")
  end

  def addcmd
    Puppet.debug "Creating group #{@resource[:name]} on system"
    pw("groupadd", "-o", "-q", "-n", @resource[:name], "-g", @resource[:gid])
  end

  def sysgroup(value)
    group_file = "/etc/group"
    group_keys = ['name', 'password', 'gid', 'members']
    name = group_keys.index('name')
    gid = group_keys.index('gid')
    File.open(group_file) do |f|
      f.each_line do |line|
         next if line =~ /^#.*/
         group = line.split(":")
         if group[name] == value and (group[gid].to_i < 2000 or group[gid].to_i > 65500)
             f.close
             return group[name]
         end
      end
    end
    false
  end

end
