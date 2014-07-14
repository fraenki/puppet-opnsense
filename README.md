#pfsense

##Table of Contents

- [Overview](#overview)
- [Module Description](#module-description)
- [Usage](#usage)
  - [Create a user](#create-a-user)
  - [Create a group](#create-a-group)
  - [pfSense facts](#pfsense-facts)
- [Reference](#reference)
  - [Feature overview](#feature-overview)
  - [Additional user parameters](#additional-user-parameters)
  - [Privileges](#privileges)
  - [Known limitations](#known-limitations)
- [Development](#development)

##Overview

This is a collection of providers and facts to manage pfSense firewalls.

NOTE: This is NOT related to the pfSense project in any way. Do NOT ask the pfSense developers for support.

##Module Description

This is intended to be a growing collection of providers and facts. In its current state it provides the following features:

* pfsense_user: a provider to manage pfSense users
* pfsense_group: a provider to manage pfSense groups
* pfsense_version: facts to gather pfSense version information

Of course, it would be desirable to have providers for packages and cronjobs too. Contributions are welcome! :-)

##Usage

###Create a user

This will create a user, but does not grant any permissions.

    pfsense_user { 'user001':
      ensure => 'present',
      password => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
      comment => 'pfsense test user',
    }

In our next example the user will have shell access (SSH) to the box and full access to the webGUI.

    pfsense_user { 'user001':
      ensure         => 'present',
      password       => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
      comment        => 'pfsense test user',
      privileges     => [ 'user-shell-access', 'page-all' ],
      authorizedkeys => [
        'ssh-rsa AAAAksdjfkjsdhfkjhsdfkjhkjhkjhkj user1@example.com',
        'ssh-rsa AAAAksdjfkjsdhfkjhsdfkjhkjhkjhkj user2@example.com',
      ],
    }

###Create a group

This will create a fully functional group:

    pfsense_group { 'group001':
      ensure  => 'present',
      comment => 'pfsense test group',
    }

In this example the group will inherit privileges to its members:

    pfsense_group { 'group001':
      ensure     => 'present',
      comment    => 'pfsense test group',
      privileges => [ 'user-shell-access', 'page-all' ],
    }

NOTE: The providers are NOT aware of privilege inheritance, see _Limitations_ for details.

###Deleting resources

This module does NOT purge unmanaged resources. So you need to define a resource as 'absent' if you want it to be removed:

    pfsense_user { 'user001':
      ensure => 'absent',
      password => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
    }

    pfsense_group { 'group001':
      ensure  => 'absent',
    }

###pfSense facts

    pfsense => true
    pfsense_version => 2.1.4-RELEASE
    pfsense_version_base => 8.3
    pfsense_version_kernel => 8.1

##Reference

###Feature overview

pfsense.rb:
* base provider, includes common functions
* read/write config.xml, clear cache, config revisions

pfsense_user.rb:
* user management
* ssh key management
* user privilege management
* account expiry

pfsense_group.rb:
* group management
* group privilege management

###Additional user parameters

To set an account expiration date:

    expiry => '2014-08-01'

To remove expiry date, set it to absent:

    expiry => 'absent'

###Privileges

You must specify user/group privileges by using the internal pfSense names. The provider will not even try to validate privilege names, because pfSense silently ignores invalid privileges.

A complete list of pfSense privileges is available in _priv.defs.inc_ from the pfSense repository:
https://github.com/pfsense/pfsense/blob/master/etc/inc/priv.defs.inc

###Known limitations

You need to be aware of the following limitations:

* No safety net. If you delete the _admin_ user your pfSense firewall is lost.
* User/group providers are NOT aware of group privilege inheritance.
* The indention of config.xml will be changed. Prepare for a huge diff when making changes.
* Removing all unmanaged resources (purge => true) is NOT supported.

##Development

Please use the github issues functionality to report any bugs or requests for new features.
Feel free to fork and submit pull requests for potential contributions.
