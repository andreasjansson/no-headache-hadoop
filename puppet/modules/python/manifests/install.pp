define python::install ($package = $title, $provider = 'pip') {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  require python

  if $provider == 'pip' {
    exec { "pip install $package":
      require => Package['python-pip'],
    }
  }
  elsif $provider == 'easy_install' {
    exec { "easy_install $package": 

    }
  }

}
