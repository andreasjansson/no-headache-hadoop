class monitoring::agent {

  include collectd

  collectd::plugin { 'load': }
  collectd::plugin { 'battery': }
  collectd::plugin { 'cpu': }
  collectd::plugin { 'df': }
  collectd::plugin { 'disk': }
  collectd::plugin { 'interface': }
  collectd::plugin { 'memory': }
  collectd::plugin { 'processes': }
  collectd::plugin { 'swap': }

  class { 'collectd::plugin::write_graphite':
    graphitehost => $nodes['monitoring'][0],
  }
  
}
