require File.join(File.dirname(__FILE__), '..', 'pfsense')
require 'rexml/document'
require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:pfsense, :parent => Puppet::Provider::Package) do
  desc "A package provider for pfSense."

  commands :pfsense_pkg => '/usr/local/sbin/pfsense_pkg'

  confine :operatingsystem => :freebsd
  confine :pfsense => :true
  defaultfor :pfsense => :true

  has_feature :upgradeable

  def install
    lock_config
    pfsense_pkg(['action=install',"pkg=#{@resource[:name]}"])
    unlock_config
    @property_hash[:ensure] = :present
  end

  def uninstall
    lock_config
    pfsense_pkg(['action=deinstall',"pkg=#{@resource[:name]}"])
    unlock_config
    @property_hash.clear
  end

  def query
    debug @property_hash
    if @property_hash[:ensure] == nil
      return nil
    else
      version = @property_hash[:version]
      return { :version => version }
    end
  end

  def version
    debug @property_hash[:version].inspect
    @property_hash[:version]
  end

  # Upgrade to the latest version
  def update
    debug 'pfsense: update called'
    uninstall
    install
  end

  # Return the latest version of the package
  def latest
    debug "pfsense: returning the latest #{@property_hash[:name].inspect} version #{@property_hash[:latest].inspect}"
    @property_hash[:latest]
  end

  def self.instances
    pfpkgs = []

    xmldoc = REXML::Document.new File.read('/cf/conf/config.xml')
    xmldoc.elements.each("pfsense/installedpackages/package"){ |e|

      name = e.elements["name"].get_text.value
      latest_version = get_latest_version(name) || e.elements["version"].get_text.value

      if defined? e.elements["descr"].get_text and defined? e.elements["descr"].get_text.value
        _descr = e.elements["descr"].get_text.value
      end

      pfpkgs << new({ 
        :name        => name,
        :ensure      => e.elements["version"].get_text.value,
        :category    => e.elements["category"].get_text.value,
        :description => _descr.nil? ? nil : _descr,
        :latest      => latest_version,
        :vendor      => e.elements["maintainer"].get_text.value,
        :version     => e.elements["version"].get_text.value,
      })
    }
    pfpkgs
  end

  def self.prefetch(resources)
    packages = instances
    resources.keys.each do |name|
      if provider = packages.find{|p| p.name == name }
        resources[name].provider = provider
      end
    end
  end

  def self.get_info
    debug 'pfsense: get_info called'
    @pkg_info = @pkg_info || pfsense_pkg(['action=info',"pkg=#{@resource[:name]}"])
    @pkg_info
  end

  def self.get_version_list
    debug 'pfsense: get_version_list called'
    @version_list = @version_list || pfsense_pkg(['action=latest','pkg=all'])
    @version_list
  end

  def self.get_latest_version(name)
    debug 'pfsense: get_latest_version called'
    if latest_version = self.get_version_list.lines.find { |l| l =~ /^#{name}/ }
      latest_version = latest_version.split(':').last.strip
      debug "pfsense: latest_version: #{name} #{latest_version}"
      return latest_version
    end
    nil
  end

end
