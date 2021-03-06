# class: mariadb::config
class mariadb::config(
    $config                         = undef,
    $password                       = undef,
    $datadir                        = '/srv/mariadb',
    $tmpdir                         = '/tmp',
    $innodb_buffer_pool_instances   = 1,
    $innodb_buffer_pool_size        = '768M',
    $server_role                    = 'master',
    $max_connections                = 90,
    $version_102                    = undef,
) {
    $server_id = inline_template(
        "<%= @ipaddress.split('.').inject(0)\
{|total,value| (total << 8 ) + value.to_i} %>"
    )

    file { '/etc/my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template($config),
    }

    file { '/etc/mysql':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { '/etc/mysql/my.cnf':
        ensure  => link,
        target  => '/etc/my.cnf',
        require => File['/etc/mysql'],
    }

    file { $datadir:
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0755',
    }

    file { $tmpdir:
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0775',
    }

    file { '/etc/mysql/miraheze':
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0755',
    }

    file { '/etc/mysql/miraheze/default-grants.sql':
        ensure  => present,
        content => template('mariadb/grants/default-grants.sql.erb'),
    }

    file { '/root/.my.cnf':
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('mariadb/config/root.my.cnf.erb'),
    }

    file { '/var/tmp/mariadb':
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0644',
    }

    exec { 'mariadb reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/mariadb.service.d/no-timeout-mariadb.conf':
        ensure => present,
        source => 'puppet:///modules/mariadb/no-timeout-mariadb.conf',
        notify => Exec['mariadb reload systemd'],
    }

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'MySQL':
            check_command => 'mysql',
            vars          => {
                mysql_username => 'icinga',
                mysql_database => 'icinga',
            },
        }
    } else {
        icinga::service { 'mysql':
            description   => 'MySQL',
            check_command => 'check_mysql!icinga',
        }
    }
}
