require File.join(File.dirname(__FILE__), '..', 'pfsense')
require 'base64'
require 'fileutils'
require 'open3'
require 'rexml/document'

Puppet::Type.type(:pfsense_user).provide(:pfsense_user, :parent => Puppet::Provider::Pfsense) do
  desc "User management on pfSense."

  commands :pw => 'pw'

  def create
    # Lock config
    lock_config

    # Fail on system users
    if !sysuser(@resource[:name])
      Puppet.debug "User #{@resource[:name]} did not match a system user"
    else
      fail "The username #{@resource['name']} is reserved by the system"
    end

    # Get next free uid
    newuid = next_uid
    @resource[:uid] = newuid
    Puppet.debug "Assigned UID #{newuid} to user #{@resource[:name]}"
    @resource[:home] = "/home/#{@resource[:name]}"

    # Configure shell type and lockstate
    _eval = eval_shell(@resource[:privileges])
    @resource[:lockstate]  = _eval['lock']
    @resource[:shell] = _eval['shell']

    # Handle authorizedkeys
    _authorizedkeys = resource[:authorizedkeys]
    _authorizedkeys = [] if resource[:authorizedkeys].include?(:absent)

    # Compose XML elements
    _user  = REXML::Element.new 'user'
    _authk = REXML::Element.new 'authorizedkeys'
    _descr = REXML::Element.new 'descr'
    _exp   = REXML::Element.new 'expires'
    _ipsec = REXML::Element.new 'ipsecpsk'
    _name  = REXML::Element.new 'name'
    _pwd   = REXML::Element.new 'password'
    _scope = REXML::Element.new 'scope'
    _uid   = REXML::Element.new 'uid'
    _authk.text = format_keys(_authorizedkeys)
    _descr.text = resource[:comment] ? REXML::CData.new(resource[:comment]) : REXML::CData.new('')
    _name.text  = resource[:name]
    _pwd.text   = resource[:password]
    _scope.text = 'user'
    _uid.text   = newuid
    _user.add_element _authk
    _user.add_element _descr
    _user.add_element _exp
    _user.add_element _ipsec
    _user.add_element _name
    _user.add_element _pwd
    _user.add_element _scope
    _user.add_element _uid

    # Add privs
    if defined?(@resource[:privileges]) and !@resource[:privileges].nil? and !@resource[:privileges].include?(:absent)
      @resource[:privileges].each do |priv|
        _priv = REXML::Element.new 'priv'
        _priv.text = priv
        _user.add_element _priv
      end
    end

    # Add user to system
    addcmd
    lockcmd(_eval['lock'].to_s) if @resource[:lockstate].to_s == 'lock'

    # Write authorizedkeys to file
    _keysdir = "/home/#{@resource[:name]}" + '/.ssh'
    _keysgroup = 'nobody'
    # Handle special user 'admin'
    if @resource[:name] == 'admin'
      _keysdir = '/root' + '/.ssh' if @resource[:name] == 'admin'
      _keysgroup = 'wheel'
    end
    _keysfile = _keysdir + '/authorized_keys'
    FileUtils::mkdir_p _keysdir || fail("Failed to create .ssh directory for user #{@resource[:name]}")
    File.open(_keysfile, 'w') do |file|
      file.write(_authorizedkeys.join("\n"))
    end
    # UID is fail-safe
    FileUtils.chown_R @resource[:uid], _keysgroup, _keysdir
    FileUtils.chmod 0600, _keysfile
    FileUtils.chmod 0700, _keysdir

    # Add user to xml configuration
    xmldoc = read_config
    xmldoc.elements["pfsense/system"].add_element _user

    # nextuid++
    nextuid = newuid.to_i
    Puppet.debug "Set next UID to #{nextuid}"
    xmldoc.elements["pfsense/system/nextuid"].text = nextuid + 1

    # Write changes to disk
    write_config(xmldoc) || fail("Failed to write config")

    # Unlock config
    unlock_config

    @property_hash[:uid] = newuid
    @property_hash[:ensure] = :present
  end

  def destroy
    # Edit XML configuration
    xmldoc = read_config
    if REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      _system = REXML::XPath.first(xmldoc, "//pfsense/system")
      _system.delete_element("user[name='#{@resource[:name]}']")
      Puppet.debug "Deleted user '#{@resource[:name]}'"
      write_config(xmldoc)
    end
    # Delete from system
    pw("userdel", @resource[:name], "-r")
    @property_hash.clear
  end

  def authorizedkeys
    @property_hash[:authorizedkeys]
  end

  def authorizedkeys=(value)
    value = [] if value.include?(:absent)
    # Write keys to file
    _keysdir = "/home/#{@resource[:name]}" + '/.ssh' 
    _keysgroup = 'nobody'
    # Handle special user 'admin'
    if @resource[:name] == 'admin'
      _keysdir = '/root' + '/.ssh' if @resource[:name] == 'admin'
      _keysgroup = 'wheel'
    end
    _keysfile = _keysdir + '/authorized_keys'
    FileUtils::mkdir_p _keysdir || fail("Failed to create .ssh directory for user #{@resource[:name]}")
    File.open(_keysfile, 'w') do |file|
      file.write(value.join("\n"))
    end
    FileUtils.chown_R @resource[:name], _keysgroup, _keysdir
    FileUtils.chmod 0600, _keysfile
    FileUtils.chmod 0700, _keysdir
    # Change xml
    xmldoc = read_config
    _keys = format_keys(value)
    if REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/authorizedkeys")
      # Change value
      _authorizedkeys = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/authorizedkeys")
      _authorizedkeys.text = _keys
    else
      # Add authorizedkeys
      _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      _authorizedkeys= REXML::Element.new 'authorizedkeys'
      _authorizedkeys.text = _keys
      _usr.add_element _authorizedkeys
    end
    write_config(xmldoc)
    @property_hash[:authorizedkeys] = value
  end

  def comment
    @property_hash[:comment]
  end

  def comment=(value)
    # Change comment
    pw("usermod", @resource[:name], "-c", "\'#{value}\'")
    # Change xml
    xmldoc = read_config
    if REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/descr")
      # Change value
      _comment  = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/descr")
      _comment.text = REXML::CData.new(value)
    else
      # Add comment
      _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      _comment = REXML::Element.new 'descr'
      _comment.text = REXML::CData.new(value)
      _usr.add_element _comment
    end
    write_config(xmldoc)
    @property_hash[:comment] = value
  end

  def expiry
    @property_hash[:expiry]
  end

  def expiry=(value)
    # FreeBSD uses DD-MM-YYYY rather than YYYY-MM-DD
    _exp = value.to_s.split("-").reverse.join("-")
    _exp = 0 if value == :absent
    pw('usermod', @resource[:name], '-e', _exp)
    # pfSense uses DD/MM/YYYY
    _pfexp = value.to_s.split("-").reverse.join("/")
    _pfexp = '' if value == :absent
    # Change xml
    xmldoc = read_config
    if REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/expires")
      # Change value
      _expires = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/expires")
      _expires.text = _pfexp
    else
      # Add comment
      _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      _expires = REXML::Element.new 'expires'
      _expires.text = _pfexp
      _usr.add_element _expires
    end
    write_config(xmldoc)
    @property_hash[:expiry]
  end

  def home
    @property_hash[:home]
  end

  def ipsecpsk
    @property_hash[:ipsecpsk]
  end

  def lockstate
    @property_hash[:lockstate]
  end

  def password
    @property_hash[:password]
  end

  def password=(value)
    # Change pw
    cmd = [command(:pw), "usermod", @resource[:name], "-H 0"].join(" ")
    stdin, stdout, stderr = Open3.popen3(cmd)
    stdin.puts(value)
    stdin.close
    # Change xml
    xmldoc = read_config
    if REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/password")
      # Change value
      _pw = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/password")
      _pw.text = value
    else
      # Add password
      _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      _pw = REXML::Element.new 'password'
      _pw.text = value
      _usr.add_element _pw
    end
    write_config(xmldoc)
    @property_hash[:password] = value
  end

  def privileges
    @property_hash[:privileges]
  end

  def privileges=(array)
    xmldoc = read_config
    array = [] if array.include?(:absent)
    # Get current privs
    privs = []
    REXML::XPath.each(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/priv"){ |p|
      privs << p.get_text.value
    }
    # Delete privs
    privs.each do |priv|
      _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
      if !array.include?(priv)
        _usr.delete_element("priv[.='#{priv}']")
        Puppet.debug "Deleted privilege '#{priv}' from user #{@resource[:name]}"
      end
    end
    # Add privs
    array.each do |value|
      if !REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']/priv[.='#{value}']")
        _usr = REXML::XPath.first(xmldoc, "//pfsense/system/user[name='#{@resource[:name]}']")
        _priv = REXML::Element.new 'priv'
        _priv.text = value
        _usr.add_element _priv
        Puppet.debug "Added privilege '#{value}' to user #{@resource[:name]}"
      end
    end
    # Change shell and lockstate
    _eval = eval_shell(array)
    pw('usermod', @resource[:name], '-s', _eval['shell'])
    Puppet.debug "Shell for user #{@resource[:name]} was to #{_eval['shell']}"
    lockcmd(_eval['lock'].to_s)
    # Write changes to disk
    write_config(xmldoc)
    @resource[:lockstate] = _eval['lock']
    @resource[:shell] = _eval['shell']
    @property_hash[:privileges] = array
  end

  def shell
    @property_hash[:shell]
  end

  def uid 
    @property_hash[:uid]
  end

  # *Discover* instances of this resource type (only *existing* resources on this system)
  def self.instances
    pfusers = []

    xmldoc = REXML::Document.new File.read('/cf/conf/config.xml')

    xmldoc.elements.each("pfsense/system/user"){ |e|
      if defined? e.elements["authorizedkeys"].get_text and defined? e.elements["authorizedkeys"].get_text.value
        _authorizedkeys = []
        Base64.decode64(e.elements["authorizedkeys"].get_text.value).split(/\r?\n|\r/).each { |line|
          _authorizedkeys << line
        }
      end
      if defined? e.elements["expires"].get_text and defined? e.elements["expires"].get_text.value
        #if e.elements["expires"].get_text.value =~ /^(\d{2})\/(\d{2})\/(\d{4})$/
        _expires = e.elements["expires"].get_text.value.split("/").reverse.join("-")
      end
      if e.elements["name"].get_text.value == 'admin'
        _home = '/root'
      else
        _home = '/home/' + e.elements["name"].get_text.value
      end
      if defined? e.elements["ipsecpsk"].get_text and defined? e.elements["ipsecpsk"].get_text.value
        _ipsecpsk = e.elements["ipsecpsk"].get_text.value
      end
      if defined? e.elements["password"].get_text and defined? e.elements["password"].get_text.value
        _password = e.elements["password"].get_text.value
      end
      if defined? e.elements["priv"].get_text and defined? e.elements["priv"].get_text.value
        _privileges = []
        e.elements.each("priv"){ |p|
          _privileges << p.get_text.value
        }
        # Evaluate shell and lockstate
        _lock = 'unlock'
        if _privileges.include?('user-shell-access') or _privileges.include?('page-all')
          _shell = '/bin/tcsh'
        elsif _privileges.include?('user-copy-files')
          _shell = '/usr/local/bin/scponly'
        elsif _privileges.include?('user-ssh-tunnel')
          _shell = '/usr/local/sbin/ssh_tunnel_shell'
        elsif _privileges.include?('user-ipsec-xauth-dialin')
          _shell = '/sbin/nologin'
        else
          _shell = '/sbin/nologin'
          _lock = 'lock'
        end
      else
        _shell = '/sbin/nologin'
        _lock = 'lock'
      end
      # Initialize @property_hash
      pfusers << new({ 
        :name           => e.elements["name"].get_text.value,
        :ensure         => :present,
        :authorizedkeys => _authorizedkeys.nil? ? [:absent] : _authorizedkeys,
        :comment        => e.elements["descr"].get_text ? e.elements["descr"].get_text.value : nil,
        :expiry         => _expires.nil? ? :absent : _expires,
        :home           => _home,
        :ipsecpsk       => _ipsecpsk.nil? ? nil : _ipsecpsk,
        :lockstate      => _lock,
        :password       => _password.nil? ? nil : _password,
        :privileges     => _privileges.nil? ? [:absent] : _privileges,
        :shell          => _shell,
        :uid            => e.elements["uid"].get_text.value,
      })
    }
    pfusers
  end

  def next_uid
    xmldoc = read_config
    xmldoc.elements["pfsense/system/nextuid"].get_text.value || fail("Failed to query next UID")
  end

  def addcmd
    Puppet.debug "Creating user #{@resource[:name]} on system"
    _comment = @resource[:comment].nil? ? nil : "-c \'#{@resource[:comment]}\'"
    cmd = [command(:pw), "useradd -m -k /etc/skel -o -q -n", @resource[:name],
           "-u", @resource[:uid], "-g nobody", "-s", @resource[:shell],
           "-d", @resource[:home], "-H 0", _comment].join(" ")
    Puppet.debug "Executing '#{cmd}'"
    stdin, stdout, stderr = Open3.popen3(cmd)
    stdin.puts(@resource[:password])
    stdin.close
  end

  def lockcmd(new_state)
    Puppet.debug "Evaluating changes required for user #{@resource[:name]} to change lockstate to '#{new_state}'"
    current_state = 'unlock'
    File.open('/etc/master.passwd') do |f|
      f.each_line do |line|
         if line =~ /^#{@resource[:name]}:\*LOCKED\*\$.*/
             Puppet.debug "User #{@resource[:name]} is currently locked"
             current_state = 'lock'
         end
         break if current_state == 'lock'
      end
    end
    if current_state != new_state
      pw(new_state, @resource[:name], "-q")
      Puppet.notice "Account for user #{@resource[:name]} was #{new_state}ed"
    end
  end

  def eval_shell(privs)
    return { 'shell' => '/sbin/nologin', 'lock' => 'lock' } unless privs.kind_of?(Array)
    _lock = 'unlock'
    # Configure shell type depending on user privilege and lock out disabled users
    if privs.include?('user-shell-access') or privs.include?('page-all')
      _shell = '/bin/tcsh'
    elsif privs.include?('user-copy-files')
      _shell = '/usr/local/bin/scponly'
    elsif privs.include?('user-ssh-tunnel')
      _shell = '/usr/local/sbin/ssh_tunnel_shell'
    elsif privs.include?('user-ipsec-xauth-dialin')
      _shell = '/sbin/nologin'
    else
      _shell = '/sbin/nologin'
      _lock = 'lock'
    end
    return { 'shell' => _shell, 'lock' => _lock }
  end

  def format_keys(array)
    return nil unless array.kind_of?(Array)
    Base64.encode64(array.join("\n"))
  end

  def sysuser(value)
    passwd_file = "/etc/passwd"
    passwd_keys = ['account', 'password', 'uid', 'gid', 'gecos', 'directory', 'shell']
    account = passwd_keys.index('account')
    uid = passwd_keys.index('uid')
    File.open(passwd_file) do |f|
      f.each_line do |line|
         next if line =~ /^#.*/
         user = line.split(":")
         if user[account] == value and (user[uid].to_i < 2000 or user[uid].to_i > 65500)
             f.close
             return user[account]
         end
      end
    end
    false
  end

end
