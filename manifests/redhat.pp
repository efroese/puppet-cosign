class cosign::redhat {
    package { [ 'openssl-devel', 'openssl-perl', 'httpd-devel' ]: ensure => installed }
}