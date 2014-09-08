# == Class: pfsense
#
# This module handles pfsense provider requirements.
#
# === Examples
#
#  class { 'pfsense':
#    pkg => false,
#  }
#
class pfsense(
  $pkg = true,
) {

  # Input validation
  include stdlib
  validate_bool($pkg)

  case $::operatingsystem {
    'FreeBSD': { }
    default: { fail("OS $::operatingsystem is not supported") }
  }

  if ! $::pfsense {
    fail("Requires a pfSense appliance")
  }

  $directory = '/usr/local/sbin'
  $pkgwrapper = 'pfsense_pkg'

  if $pkg {

    file { "${directory}/${pkgwrapper}":
      ensure  => file,
      source  => "puppet:///modules/${module_name}/${pkgwrapper}",
      owner   => root,
      group   => wheel,
      mode    => '0755',
    }

  }

}
