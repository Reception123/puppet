class httpd(
    $modules = [],
    $legacy_compat = present,
    $period = 'daily',
    $rotate = 30,
) {
    # Package and service. Links is needed for the status page below
    require_package('apache2', 'links')

    # Puppet restarts are reloads in apache, as typically that's enough
    service { 'apache2':
        ensure     => running,
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
        restart    => '/usr/sbin/service apache2 reload',
    }

    # When it's not, as is the case for module insertion, have a safe hard restart option
    exec { 'apache2_test_config_and_restart':
        command     => '/usr/sbin/service apache2 restart',
        onlyif      => '/usr/sbin/apache2ctl configtest',
        before      => Service['apache2'],
        refreshonly => true,
    }

    # Ensure the directories for apache config files are in place.
    file { '/etc/apache2/conf-available':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/etc/apache2/conf-enabled':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => true,
        purge   => true,
        notify  => Service['apache2'],
    }

    file { '/etc/apache2/env-available':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/etc/apache2/env-enabled':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => true,
        purge   => true,
        notify  => Service['apache2'],
    }

    file { '/etc/apache2/sites-available':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/etc/apache2/sites-enabled':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => true,
        purge   => true,
        notify  => Service['apache2'],
    }

    file_line { 'load_env_enabled':
        line  => 'for f in /etc/apache2/env-enabled/*.sh; do [ -r "$f" ] && . "$f" >&2; done || true',
        match => 'env-enabled',
        path  => '/etc/apache2/envvars',
    }

    # Default boilerplate configs
    httpd::conf { 'defaults':
        source   => 'puppet:///modules/httpd/defaults.conf',
        priority => 0,
    }

    httpd::site { 'dummy':
        source   => 'puppet:///modules/httpd/dummy.conf',
        priority => 0,
    }

    # manage logrotate periodicity and keeping period
    #
    # The augeas rule in apache::logrotate needs /etc/logrotate.d/apache2 which
    # is provided by package apache2
    augeas { 'Apache2 logs':
        lens    => 'Logrotate.lns',
        incl    => '/etc/logrotate.d/apache2',
        changes => [
            "set rule/schedule ${period}",
            "set rule/rotate ${rotate}",
        ],
    }

    # Apache httpd 2.2 compatibility
    httpd::mod_conf { ['filter', 'access_compat']:
        ensure => $legacy_compat,
    }


    httpd::mod_conf { concat(['status'], $modules):
        ensure => present
    }


    # The default mod_status configuration enables /server-status on all vhosts for
    # local requests, but it does not correctly distinguish between requests which
    # are truly local and requests that have been proxied. Because most of our
    # Apaches sit behind a reverse proxy, the default configuration is not safe, so
    # we make sure to replace it with a more conservative configuration that makes
    # /server-status accessible only to requests made via the loopback interface.
    # See T113090.

    file { [
        '/etc/apache2/mods-available/status.conf',
        '/etc/apache2/mods-enabled/status.conf',
    ]:
        ensure  => absent,
        before  => Httpd::Mod_conf['status'],
        require => Package['apache2'],
    }


    # server status page
    httpd::conf { 'server-status':
        source   => 'puppet:///modules/httpd/status.conf',
        priority => 50,
        require  => Httpd::Mod_conf['status'],
    }

    # Check the status
    file { '/usr/local/bin/apache-status':
        source => 'puppet:///modules/httpd/apache-status',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }
}
