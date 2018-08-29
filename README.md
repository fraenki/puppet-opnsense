#### Table of Contents

- [Overview](#overview)
- [Module Description](#module-description)
- [Usage](#usage)
  - [Create a user](#create-a-user)
  - [Create a group](#create-a-group)
  - [OPNsense facts](#opnsense-facts)
- [Reference](#reference)
  - [Feature overview](#feature-overview)
  - [Additional user parameters](#additional-user-parameters)
  - [Privileges](#privileges)
  - [Known limitations](#known-limitations)
- [Development](#development)

## Overview

This is a collection of providers and facts to manage OPNsense firewalls.

NOTE: This is NOT related to the OPNsense project in any way. Do NOT ask the OPNsense developers for support.

## Module Description

This is intended to be a growing collection of providers and facts. In its current state it provides the following features:

* opnsense_user: a provider to manage OPNsense users
* opnsense_group: a provider to manage OPNsense groups
* opnsense_version: facts to gather OPNsense version information

Of course, it would be desirable to have a provider for cronjobs too. Contributions are welcome! :-)

## Usage

### Create a user

This will create a user, but does not grant any permissions.

    opnsense_user { 'user001':
      ensure   => 'present',
      password => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
      comment  => 'opnsense test user',
    }

In our next example the user will have shell access (SSH) to the box and full access to the webGUI.

    opnsense_user { 'user001':
      ensure         => 'present',
      password       => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
      comment        => 'opnsense test user',
      privileges     => [ 'user-shell-access', 'page-all' ],
      authorizedkeys => [
        'ssh-rsa AAAAksdjfkjsdhfkjhsdfkjhkjhkjhkj user1@example.com',
        'ssh-rsa AAAAksdjfkjsdhfkjhsdfkjhkjhkjhkj user2@example.com',
      ],
    }

### Create a group

This will create a fully functional group:

    opnsense_group { 'group001':
      ensure  => 'present',
      comment => 'opnsense test group',
    }

In this example the group will inherit privileges to its members:

    opnsense_group { 'group001':
      ensure     => 'present',
      comment    => 'opnsense test group',
      privileges => [ 'user-shell-access', 'page-all' ],
    }

NOTE: The providers are NOT aware of privilege inheritance, see _Limitations_ for details.

### Deleting resources

This provider does NOT purge unmanaged resources. So you need to define a resource as 'absent' if you want it to be removed:

    opnsense_user { 'user001':
      ensure   => 'absent',
      password => '$1$dSJImFph$GvZ7.1UbuWu.Yb8etC0re.',
    }

    opnsense_group { 'group001':
      ensure  => 'absent',
    }

### OPNsense facts

    opnsense => true
    opnsense_version => 16.7.a_52-e82bcae6e
    opnsense_major => 16
    opnsense_minor => 7
    opnsense_patchlevel => a_52
    opnsense_revision => e82bcae6e

## Reference

### Feature overview

opnsense.rb:
* base provider, includes common functions
* read/write config.xml, clear cache, config revisions

opnsense_user.rb:
* user management
* ssh key management
* user privilege management
* account expiry

opnsense_group.rb:
* group management
* group privilege management

###Additional user parameters

To set an account expiration date:

    expiry => '2014-08-01'

To remove expiry date, set it to absent:

    expiry => 'absent'

### Privileges

You must specify user/group privileges by using the internal OPNsense names. The provider will not even try to validate privilege names, because OPNsense silently ignores invalid privileges.

A complete list of OPNsense privileges is available from the OPNsense repository:
https://github.com/opnsense/core/blob/81f1d2552e863f4c2edf7e3eb1fe066cbdcbf177/src/opnsense/mvc/app/models/OPNsense/Core/ACL/ACL.xml

### Known limitations

You need to be aware of the following limitations:

* No safety net. If you delete the _root_ user your OPNsense firewall is lost.
* User/group providers are NOT aware of group privilege inheritance.
* The indention of config.xml will be changed. Prepare for a huge diff when making changes.
* Removing all unmanaged resources (purge => true) is NOT supported.

## Development

Please use the github issues functionality to report any bugs or requests for new features.
Feel free to fork and submit pull requests for potential contributions.

## Legal

OPNsense® is Copyright © 2014 – 2018 by Deciso B.V. All rights reserved.
