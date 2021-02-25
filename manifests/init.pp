#
#
#
class carbon_c_relay (
  $clusters,
  $matches,
  Stdlib::Absolutepath $config_file         = '/etc/carbon-c-relay.conf',
  Stdlib::Absolutepath $sysconfig           = '/etc/sysconfig/carbon-c-relay',
  String               $service_name        = 'carbon-c-relay',
  String               $package_name        = 'carbon-c-relay',
  String               $default_algorithm   = 'fnv1a_ch',

  Integer              $port                = 2003,
  String               $interface           = '',
  Integer              $workers             = 4,
  Integer              $batch_size          = 2500,
  Integer              $queue_size          = 25000,
  Integer              $statistics_interval = 60,
  Integer              $connection_backlog  = 32,
  Integer              $timeout             = 600,
  Boolean              $send_statistics     = false,
  String               $extra_characters    = '',
  Boolean              $debug               = false,
  Stdlib::Fqdn         $fqdn                = $::fqdn,
) {

  package { $package_name:
    ensure => present,
  }

  service { $service_name:
    ensure => running,
  }

  concat { $config_file:
    ensure => present,
    notify => Service[$service_name],
  }

  concat::fragment { "${config_file}_header":
    target  => $config_file,
    order   => '10',
    content => "# File managed by puppet ( ${module_name}\n",
  }

  $clusters.each | $cluster_name, $settings | {
    $_cluster = {
      'cluster_name'      => $cluster_name,
      'cluster_algorithm' => pick($settings['algorithm'], $default_algorithm),
      'caches'            => $settings['caches'],
    }
    concat::fragment { "${config_file}_clusters":
      target  => $config_file,
      order   => '20',
      content => epp("${module_name}/config/cluster", $_cluster),
    }
  }

  $matches.each | $match, $settings | {
    $_match = {
      'match'  => $match,
      'action' => $settings['action'],
      'stop'   => pick($settings['stop'], false),
    }
    concat::fragment { "${config_file}_matches":
      target  => $config_file,
      order   => '20',
      content => epp("${module_name}/config/match", $_match),
    }
  }

  $_sysconfig = {
    'port'                => [$port, '-p'],
    'interface'           => [$interface, '-i'],
    'workers'             => [$workers, '-w'],
    'batch_size'          => [$batch_size, '-b'],
    'queue_size'          => [$queue_size, '-q'],
    'statistics_interval' => [$statistics_interval, '-S'],
    'connection_backlog'  => [$connection_backlog, '-B'],
    'timeout'             => [$timeout, '-T'],
    'send_statistics'     => [$send_statistics, '-m'],
    'extra_characters'    => [$extra_characters, '-c'],
    'debug'               => [$debug, '-d'],
    'hostname'            => [$fqdn, '-H'],
  }

  $_args = $_sysconfig.map | $option, $config | {
    case $config[0] {
      true:      { $_r = $config[1] }
      false, '': { $_r = '' }
      default:   { $_r = "${config[1]} '${config[0]}'" }
    }
    $_r
  }.filter | $value | { ! empty( $value ) }.join(' ')

  file { $sysconfig:
    ensure  => present,
    content => epp("${module_name}/config/sysconfig", { 'args' => $_args }),
    notify  => Service[$service_name],
  }
}
