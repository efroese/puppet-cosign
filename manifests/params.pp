class cosign::params {

    Class['Apache::Params'] -> Class['Cosign::Params']

    $apache_modules_dir = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ => '/usr/lib64/httpd/modules',
        /Debian|Ubuntu/        => '/usr/lib/apache2/modules',
    }

    $ssl_dir = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ => '/etc/httpd/ssl',
        /Debian|Ubuntu/        => '/etc/apache2/ssl',
    }

    $source = "/var/cache/cosign/source"
}