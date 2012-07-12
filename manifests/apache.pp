#
# = Class cosign::apache
# Build and install the cosign apache module.
#
# = Parameters
#
# $domain               The cosign domain for this install
# $identifier           The Specified string for the cosign install
# $issuance integer     The cosign issuance identifier
# $key_file             Your cosign key
# $crt_file             Your cosign certificate
# 
class cosign::apache(
    $domain,
    $identifier,
    $issuance_integer,
    $key_file,
    $crt_file,
    $ca_cert_pem_file){

    Class['Cosign::Params'] -> Class['Cosign::Apache']
    Class['Apache']         -> Class['Cosign::Apache']
    
    case $::operatingsystem {
        /Redhat|CentOS|Amazon/ : { class { 'cosign::redhat': } }
        /Debian|Ubuntu/        : { class { 'cosign::debian': } }
    }
    
    $full_identifier = "${domain}=${identifier}-${issuance_integer}"

    file { [ $cosign::params::ca_dir, $cosign::params::ssl_dir, ]:
        ensure => directory,
        owner  => root,
        group  => root,
    }

    file { "${cosign::params::ssl_dir}/full_identifier.key":
        owner   => $apache::user,
        group   => $apache::group,
        mode    => 0660,
        source  => $key_file,
        require => File[$cosign::params::ssl_dir],
    }

    file { "${cosign::params::ssl_dir}/full_identifier.crt":
        owner   => root,
        group   => $apache::group,
        mode    => 0660,
        source  => $crt_file,
        require => File[$cosign::params::ssl_dir],
    }

    file { "${cosign::params::ca_dir}/ca-cert.pem":
        owner   => $apache::user,
        group   => $apache::group,
        mode    => 0644,
        source  => $ca_cert_pem_file,
        require => File[$cosign::params::ca_dir],
        notify  => Exec["c_rehash ${cosign::params::ca_dir}"]
    }

    exec { "c_rehash ${cosign::params::ca_dir}":
        command     => "c_rehash ${cosign::params::ca_dir}",
        refreshonly => true,
    }

    file { '/var/cache/cosign':
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
    }

    file { '/var/cache/cosign/filter':
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
        require => File['/var/cache/cosign'],
    }

    file { $cosign::params::source:
        ensure => directory,
        owner  => $apache::user,
        group  => $apache::group,
        require => File['/var/cache/cosign'],
    }

    # Extract /var/lib/cosign/domain-string-int.zip -> 
    # /var/lib/cosign/domain-string-int 
    archive::extract { "${full_identifier}.zip":
        target     => $cosign::params::source,
        src_target => $cosign::params::source,
        extension  => 'zip',
        require    => File[$cosign::params::source],
        notify     => Exec['configure-cosign-module'],
    }

    exec { 'configure-cosign-module':
        command     => $::operatingsystem ? {
            /RedHat|CentOS|Amazon/ => './configure --enable-apache2=/usr/sbin/apxs',
            /Debian|Ubuntu/        => './configure --enable-apache2=/usr/sbin/apxs2',
        },
        cwd         => "${cosign::params::source}/${full_identifier}",
        refreshonly => true,
        notify      => Exec['install-cosign-module']
    }

    exec { 'install-cosign-module':
        command     => "make && make install",
        cwd         => "${cosign::params::source}/${full_identifier}",
        refreshonly => true,
    }

    apache::module { 'cosign':
        ensure => present,
    }
}