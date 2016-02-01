require 'puppet/property/list'
Puppet::Type.newtype(:opnsense_group) do

  desc 'Manage additional groups on OPNsense.'

  ensurable

  newparam(:name, :namevar => true) do
    desc 'The name of the group.'
    validate do |value|
      fail('The groupname must not be longer than 16 characters.') if value.length > 16
    end
  end

  newproperty(:comment) do
    desc "A description of the group."
    munge do |value|
      case value
      when 
        if value =~ /[!@:]+/
          value = value.gsub(/!|@|:/, '')
          self.warning "Removed invalid characters from comment for group"
        end
      end
      value.respond_to?(:force_encoding) ? value.force_encoding(Encoding::ASCII_8BIT) : value
    end
  end

  newproperty(:privileges, :array_matching => :all) do
    validate do |value|
      unless value.nil? or value =~ /^[-a-z0-9A-Z_]+$/
        raise Puppet::Error, "Privilege #{value} is not valid."
      end
    end
    defaultto [:absent]
  end

  newproperty(:gid) do
    desc 'The unique ID of the group.'
  end

end
