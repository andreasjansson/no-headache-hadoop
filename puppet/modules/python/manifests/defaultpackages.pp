class python::defaultpackages {

  package { 'python-simplejson':
    ensure => present,
  }

  package { 'python-scipy':
    ensure => present,
  }

  package { 'python-sklearn':
    ensure => present,
  }

  package { 'libmagic1':
    ensure => present,
  }

  python::install { 'filemagic':
    require => Package['libmagic1'],
  }

}
