class cosign::params {

    $apache_user = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ =>   'apache' ,
        /Debian|Ubuntu/        =>   'www-data' ,
    }

    $apache_group = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ =>   'apache' ,
        /Debian|Ubuntu/        =>   'www-data' ,
    }

    $apache_modules_dir = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ => '/usr/lib64/httpd/modules',
        /Debian|Ubuntu/        => '/usr/lib/apache2/modules',
    }    

    $ca_dir = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ => '/etc/httpd/cosign-ca',
        /Debian|Ubuntu/        => '/etc/apache2/cosign-ca',
    }

    $ssl_dir = $::operatingsystem ? { 
        /RedHat|CentOS|Amazon/ => '/etc/httpd/ssl',
        /Debian|Ubuntu/        => '/etc/apache2/ssl',
    }

    $source = "/var/cache/cosign/source"
}