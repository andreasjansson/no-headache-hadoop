class tools {

  package { 'unzip':
    ensure => present,
  }

  package { 'emacs24-nox':
    ensure => present,
  }

  package { 'rlwrap':
    ensure => present,
  }
  
}
