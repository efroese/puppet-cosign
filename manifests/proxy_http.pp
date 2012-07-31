#
# = Class cosign::proxy_http
# Pass the REMOTE_USER header through mod_proxy_http as $header_name
# We have to use this since if we use mod_proxy_http since it doesn't
# pass REMOTE_USER through
# 
class cosign::proxy_http(
    $vhost_name,
    $header_name='Proxy-User') { 

    Class['Cosign::Params'] -> Class['Cosign::Proxy_http']
    
    apache::conf { "cosign mod proxy remote user passthrough":
        ensure       => present,
        path          => "${apache::params::root}/${vhost_name}/conf",
        configuration => template('cosign/proxy_http_fix.erb'),
    }
}
