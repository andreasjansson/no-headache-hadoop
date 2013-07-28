class pig {

  require hadoop

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }
  File { owner => 'hadoop', }

  $remote_path = 'http://mirror.ox.ac.uk/sites/rsync.apache.org/pig/stable/pig-0.11.1.tar.gz'
  $download_path = '/tmp/pig-0.11.1.tar.gz'
  $extract_dir = '/opt'
  $real_root = '/opt/pig-0.11.1'
  $root = '/opt/pig'

  util::tarball { 'pig':
    download_path => $download_path,
    extract_dir => $extract_dir,
    extracted_dir => $real_root,
    user => 'hadoop',
    require => User['hadoop'],
  }

  file { $root:
    ensure => 'link',
    target => $real_root,
    require => Util::Tarball['pig'],
  }
  
  file { '/etc/profile.d/pig_env.sh':
    source => 'puppet:///modules/pig/pig_env.sh',
  }

}
