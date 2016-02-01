require 'puppet/property/list'
Puppet::Type.newtype(:opnsense_user) do

  desc 'Manage additional users on OPNsense.'

  ensurable

  validate do
    fail('Password is required.') if self[:ensure] == :present and self[:password].nil?
  end

  newparam(:name, :namevar => true) do
    desc 'The name of the user.'
    validate do |value|
      fail('The username must not be longer than 16 characters.') if value.length > 16
    end
  end

  newproperty(:authorizedkeys, :array_matching => :all) do
    desc 'Autorized keys for SSH logon.'
    #validate do |value|
    #  unless value.nil? or value =~ /^[a-z0-9A-Z_+\-\.\/=@]*$/
    #    raise Puppet::Error, "Authorized Key #{value} is not valid."
    #  end
    #end
    #def is_to_s(value)
    #  if value.nil?
    #    super
    #  else
    #    return value if value.include?(:absent)
    #    value.join(",")
    #  end
    #end
    #alias :should_to_s :is_to_s
    #def change_to_s(current_value, newvalue)
    #  if current_value == :absent
    #    # silence
    #  elsif newvalue == :absent or newvalue == [:absent]
    #    return "undefined '#{name}' from #{self.class.format_value_for_display is_to_s(current_value)}"
    #  else
    #    return "#{name} changed #{self.class.format_value_for_display is_to_s(current_value)} to #{self.class.format_value_for_display should_to_s(newvalue)}"
    #  end
    #end
    # Remove all authorizedkeys by default
    defaultto [:absent]
  end

  newproperty(:comment) do
    desc "A description of the user. Generally the user's full name."
    munge do |value|
      case value
      when 
        if value =~ /[!@:]+/
          value = value.gsub(/!|@|:/, '')
          self.warning "Removed invalid characters from comment for user "
        end
      end
      value.respond_to?(:force_encoding) ? value.force_encoding(Encoding::ASCII_8BIT) : value
    end
  end

  newproperty(:expiry) do
    desc "The expiry date for this user. Must be provided in
         a zero-padded YYYY-MM-DD format --- e.g. 2012-12-31.
         If you want to make sure the user account does never
         expire, you can pass the special value `absent`."

    newvalues :absent
    newvalues /^\d{4}-\d{2}-\d{2}$/

    validate do |value|
      if value.intern != :absent and value !~ /^\d{4}-\d{2}-\d{2}$/
        raise ArgumentError, "Expiry dates must be YYYY-MM-DD or the string \"absent\""
      end
    end
    defaultto :absent
  end

  newproperty(:home) do
    desc 'The home directory of the user. Automatically set depending on user role.'
  end

  newproperty(:ipsecpsk) do
    desc 'IPsec pre-shared key.'
    # XXX: validate
  end

  newproperty(:lockstate) do
    desc 'The lockout status of the user. Automatically set depending on user privileges.'
  end

  newproperty(:password) do
    desc %q{The user's password, in whatever encrypted format.}
    validate do |value|
      raise ArgumentError, "Passwords cannot include ':'" if value.is_a?(String) and value.include?(":")
      fail('The password must be crypted.') unless value =~ /^\$[1-9a-z]+\$.*/
    end
  end

  newproperty(:privileges, :array_matching => :all) do
    validate do |value|
      unless value.nil? or value =~ /^[-a-z0-9A-Z_]+$/
        raise Puppet::Error, "Privilege #{value} is not valid."
      end
    end
    # Remove all privileges by default
    defaultto [:absent]
  end

  newproperty(:shell) do
    desc 'The shell of the user. Automatically assigned depending on user privileges.'
  end

  newproperty(:uid) do
    desc 'The unique ID of the user.'
  end

end
