class cosign::debian {
    package { [ 'libssl-devel', 'libssl0.9.8', ]: ensure => installed }
}