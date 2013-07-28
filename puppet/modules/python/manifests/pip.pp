define puppet::pip::install($package = $title) {
  exec { "pip install $package":
    require => Class['python'],
  }
}
