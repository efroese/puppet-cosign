#
# == Class: cosign::apache
# Build and install the cosign apache module.
#
# === Parameters
#
# [*domain*]
#		The cosign domain for this install
# [*identifier*]
#		The Specified string for the cosign install
# [*issuance_integer*]
#		The cosign issuance identifier
# [*key_file*]
#		Your cosign key
# [*crt_file*]
#		Your cosign certificate
# [*vhost_name*]
#		The name of the apache::vhost[-ssl] to activate cosign in
# [*mod_cosign_source*]
#		The name of the source tarball
# [*vhost_config_template*]
#		An optional template for the cosign base vhost config
# [*location_config_template*]
#		An optional template for the /cosign/valid configuration.
# 
# === Examples
# First copy your source to /var/cache/cosign/source
# For this example we'll use /var/cache/cosign/source/cosign3-090824-2.tgz
#
# class { 'cosign::apache':
#    domain            => 'test',
#    identifier        => 'app0,
#    issuance_integer  => 2,
#    key_file          => 'puppet:///modules/site/test-app0-2.key',
#    crt_file          => 'puppet:///modules/site/test-app0-2.crt',
#    ca_cert_pem_file  => 'puppet:///modules/site/cosign-int.pem',
#    vhost_name        => 'cosign.protected.example.edu:443',
#    mod_cosign_source => 'cosign3-090824-2,
# }
#
# apache::conf { 'cosign protection':
#    ensure => present,
#    path   => "${apache::params::root}/cosign.protected.example.edu:443/conf",
#    configuration => "
#    <Location /app0/authentication >
#        CosignProtected On
#        AuthType Cosign
#        Require valid-user
#        CosignRequireFactor   UPENN.EDU
#    </Location>",
# }

class cosign::apache(
    $domain,
    $identifier,
    $issuance_integer,
    $key_file,
    $crt_file,
    $ca_cert_pem_file,
    $vhost_name,
    $mod_cosign_source,
    $vhost_config_template    = 'cosign/vhost_config.erb',
    $location_config_template = 'cosign/location_config.erb'){

    Class['Cosign::Params'] -> Class['Cosign::Apache']
    
    class { 'cosign::params': }

    case $::operatingsystem {
        /Redhat|CentOS|Amazon/ : { class { 'cosign::redhat': } }
        /Debian|Ubuntu/        : { class { 'cosign::debian': } }
    }
    
    $full_identifier = "${domain}-${identifier}-${issuance_integer}"
    $ca_dir          = "${apache::params::conf}/cosign-ca"
    $ssl_dir         = "${apache::params::conf}/cosign-ssl"
    $cache_dir       = '/var/cache/cosign'

    $host            = regsubst($vhost_name, ':\d+$', '')
    $escaped_url     = regsubst("https://${host}", '([\.])', '\\\1', 'G')
    $valid_reference = "${escaped_url}/.*"

    file { [ $ca_dir, $ssl_dir, ]:
        ensure => directory,
        owner  => root,
        group  => root,
    }

    file { "${ssl_dir}/${full_identifier}.key":
        owner   => $apache::user,
        group   => $apache::group,
        mode    => 0660,
        source  => $key_file,
        require => File[$ssl_dir],
    }

    file { "${ssl_dir}/${full_identifier}.crt":
        owner   => root,
        group   => $apache::group,
        mode    => 0660,
        source  => $crt_file,
        require => File[$ssl_dir],    }


    file { "${ca_dir}/ca-cert.pem":
        owner   => $apache::user,
        group   => $apache::group,
        mode    => 0644,
        source  => $ca_cert_pem_file,
        require => File[$ca_dir],
        notify  => Exec["c_rehash ${ca_dir}"]
    }

    exec { "c_rehash ${ca_dir}":
        command     => "c_rehash ${ca_dir}",
        refreshonly => true,
    }

    file { $cache_dir:
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
    }

    file { '/var/cache/cosign/filter':
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
        require => File[$cache_dir],
    }

    file { $cosign::params::source:
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
        require => File[$cache_dir],
    }

    # Extract /var/lib/cosign/domain-string-int.zip -> 
    # /var/lib/cosign/domain-string-int 
    archive::extract { $mod_cosign_source:
        target     => $cosign::params::source,
        src_target => $cosign::params::source,
        extension  => 'tgz',
        require    => File[$cosign::params::source],
        notify     => Exec['configure-cosign-module'],
    }

    exec { 'configure-cosign-module':
        command     => $::operatingsystem ? {
            /RedHat|CentOS|Amazon/ => "${cosign::params::source}/${mod_cosign_source}/configure --enable-apache2=/usr/sbin/apxs",
            /Debian|Ubuntu/        => "${cosign::params::source}/${mod_cosign_source}/configure --enable-apache2=/usr/sbin/apxs2",
        },
        cwd         => "${cosign::params::source}/${mod_cosign_source}",
        refreshonly => true,
        notify      => Exec['install-cosign-module']
    }

    exec { 'install-cosign-module':
        command     => "make && make install",
        cwd         => "${cosign::params::source}/${mod_cosign_source}",
        refreshonly => true,
    }

    file { "${apache::params::conf}/mods-available/zz_cosign.load":
	owner   => root,
	group   => root,
        mode    => 0644,
        content => 'LoadModule cosign_module modules/mod_cosign.so',
    }

    apache::module { 'zz_cosign':
        ensure  => present,
        require => [ File[ "${apache::params::conf}/mods-available/zz_cosign.load"],
                     Exec['install-cosign-module'], ],
    }

    # aaa forces this file to load before the location config
    apache::conf { 'cosign aaa vhost':
        ensure => present,
        path   => "${apache::params::root}/${vhost_name}/conf",
        configuration => template($vhost_config_template),
    }

    apache::conf { 'cosign location':
        ensure => present,
        path   => "${apache::params::root}/${vhost_name}/conf",
        configuration => template($location_config_template),
    }

    cron { 'cosign-session-cleanup':
        ensure  => present,
        minute  => 13,
        hour    => 0,
        command => "find ${cache_dir} -type f -mtime +1 | xargs rm -f",
    }
}
