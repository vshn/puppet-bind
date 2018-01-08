# ex: syntax=puppet si ts=4 sw=4 et

class bind (
    $confdir       = undef,
    $cachedir      = undef,
    $forwarders    = undef,
    $dnssec        = undef,
    $version       = undef,
    $rndc          = undef,
    $notify_to_soa = false,
) {
    include ::bind::params

    $auth_nxdomain = false

    File {
        ensure  => present,
        owner   => 'root',
        group   => $::bind::params::bind_group,
        mode    => '0644',
        require => Package['bind'],
        notify  => Service['bind'],
    }

    package { 'bind':
        ensure => latest,
        name   => $::bind::params::bind_package,
    }

    file { $::bind::params::bind_files:
        ensure  => present,
    }

    if $dnssec {
        file { '/usr/local/bin/dnssec-init':
            ensure => present,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
            source => 'puppet:///modules/bind/dnssec-init',
        }
    }

    file { [ $confdir, "${confdir}/zones" ]:
        ensure  => directory,
        mode    => '2755',
        purge   => true,
        recurse => true,
    }

    file { "${confdir}/named.conf":
        content => template('bind/named.conf.erb'),
    }

    if $rndc {
        exec { 'generate-bind-rndc.conf':
            command => "/usr/sbin/rndc-confgen -r /dev/urandom -a -c ${confdir}/rndc.key",
            creates => "${confdir}/rndc.key",
        }->
        file { "${confdir}/rndc.key":
            ensure => file,
            owner  => 'root',
            group  => $::bind::params::bind_group,
            mode   => '0440',
        }
    }

    class { 'bind::keydir':
        keydir => "${confdir}/keys",
    }

    concat { [
        "${confdir}/acls.conf",
        "${confdir}/keys.conf",
        "${confdir}/views.conf",
        ]:
        owner   => 'root',
        group   => $::bind::params::bind_group,
        mode    => '0644',
        require => Package['bind'],
        notify  => Service['bind'],
    }

    concat::fragment { 'named-acls-header':
        order   => '00',
        target  => "${confdir}/acls.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    concat::fragment { 'named-keys-header':
        order   => '00',
        target  => "${confdir}/keys.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    concat::fragment { 'named-keys-rndc':
        order   => '99',
        target  => "${confdir}/keys.conf",
        content => "#include \"${confdir}/rndc.key\"\n",
    }

    concat::fragment { 'named-views-header':
        order   => '00',
        target  => "${confdir}/views.conf",
        content => "# This file is managed by puppet - changes will be lost\n",
    }

    service { 'bind':
        ensure     => running,
        name       => $::bind::params::bind_service,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
    }
}
