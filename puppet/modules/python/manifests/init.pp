class python {

  package { 'python2.7':
    ensure => present,
  }

  package { 'python-pip':
    ensure => present,
  }


}
