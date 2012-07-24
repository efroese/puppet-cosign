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
    $ca_cert_pem_file,
    $vhost_name){

    Class['Cosign::Params'] -> Class['Cosign::Apache']
    
    class { 'cosign::params': }

    case $::operatingsystem {
        /Redhat|CentOS|Amazon/ : { class { 'cosign::redhat': } }
        /Debian|Ubuntu/        : { class { 'cosign::debian': } }
    }
    
    $full_identifier = "${domain}-${identifier}-${issuance_integer}"
    $ca_dir          = "${apache::params::conf}/cosign-ca"
    $ssl_dir         = "${apache::params::conf}/cosign-ssl"

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
    archive::extract { $full_identifier:
        target     => $cosign::params::source,
        src_target => $cosign::params::source,
        extension  => 'tgz',
        require    => File[$cosign::params::source],
        notify     => Exec['configure-cosign-module'],
    }

    exec { 'configure-cosign-module':
        command     => $::operatingsystem ? {
            /RedHat|CentOS|Amazon/ => "${cosign::params::source}/${full_identifier}/configure --enable-apache2=/usr/sbin/apxs",
            /Debian|Ubuntu/        => "${cosign::params::source}/${full_identifier}/configure --enable-apache2=/usr/sbin/apxs2",
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

    file { "${apache::params::conf}/mods-available/cosign.load":
	owner   => root,
	group   => root,
        mode    => 0644,
        content => 'LoadModule cosign_module modules/mod_cosign.so',
    }

    apache::module { 'cosign':
        ensure  => present,
        require => [ File[ "${apache::params::conf}/mods-available/cosign.load"],
                     Exec['install-cosign-module'], ],
    }

    apache::conf { 'cosign vhost':
        ensure => present,
        path   => "${apache::params::root}/${vhost_name}/conf",
        configuration => "
        CosignProtected off
        CosignHostname weblogin.pennkey.upenn.edu
        CosignCheckIP never
        CosignService ${full_identifier}
        CosignRedirect https://weblogin.pennkey.upenn.edu/login
        CosignPostErrorRedirect https://weblogin.pennkey.upenn.edu/post_error.html
        CosignFilterDB /var/cache/cosign/filter
        CosignCrypto ${ssl_dir}/${full_identifier}.key ${ssl_dir}/${full_identifier}.crt ${ca_dir}
        "
    }

    apache::conf { 'cosign location':
        ensure => present,
        path   => "${apache::params::root}/${vhost_name}/conf",
        configuration => "
        <Location /cosign/valid>
             SetHandler cosign
             CosignProtected off
             Allow from all
             Satisfy any
             CosignHostname weblogin.pennkey.upenn.edu
             CosignCrypto ${ssl_dir}/${full_identifier}.key ${ssl_dir}/${full_identifier}.crt ${ca_dir}
             CosignValidReference          https://${vhost_name}/.*
             CosignValidationErrorRedirect http://weblogin.pennkey.upenn.edu/validation_error.html
        </Location>
        ",
    }
}