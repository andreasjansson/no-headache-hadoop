class graphite::install {

  package {[
    'python-ldap',
    'python-cairo',
    'python-django',
    'python-twisted',
    'python-django-tagging',
    'python-simplejson',
    'python-memcache',
    'python-pysqlite2',
    'python-support',
    'python-pip',
  ]:
    ensure => latest;
  }

  package { 'carbon':
    ensure => installed,
    provider => pip,
  }

  package { 'graphite-web':
    ensure => installed,
    provider => pip,
  }

  package { 'whisper':
    ensure   => installed,
    provider => pip,
  }

  file { '/var/log/carbon':
    ensure => directory,
    owner  => www-data,
    group  => www-data,
  }

}
