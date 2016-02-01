# == Class: opnsense
#
# This module handles opnsense provider requirements.
#
# === Examples
#
#  class { 'opnsense': }
#
class opnsense {

  case $::operatingsystem {
    'FreeBSD': { }
    default: { fail("OS $::operatingsystem is not supported") }
  }

  if ! $::opnsense {
    fail("Requires a OPNsense appliance")
  }

}
