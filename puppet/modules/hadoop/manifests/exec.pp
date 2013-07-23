define hadoop::exec($command = $title) {
  include hadoop::params

  exec { $command:
    path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/",  "${hadoop::params::root}/bin" ],
    user => 'hadoop',
  }

}
