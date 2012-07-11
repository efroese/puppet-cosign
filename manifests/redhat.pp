class cosign::redhat {
    package { [ 'openssl-devel', 'openssl-perl', ]: ensure => installed }
}