class hadoop::base {
  require hadoop::params

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }
  File { owner => 'hadoop', }

  $remote_path = 'http://apache.mirror.anlx.net/hadoop/common/hadoop-1.1.2/hadoop-1.1.2.tar.gz'
  $download_path = '/tmp/hadoop-1.1.2.tar.gz'
  $extract_dir = '/opt'
  $real_root = '/opt/hadoop-1.1.2'

  user { 'hadoop':
    ensure => present,
    shell => '/bin/bash',
    home => '/home/hadoop',
  }

  file { '/home/hadoop':
    ensure => directory,
  }

  file { '/home/hadoop/.ssh':
    ensure => directory,
    require => File['/home/hadoop'],
    mode => '700',
  }

  file { '/home/hadoop/.ssh/id_rsa':
    ensure => present,
    source => 'puppet:///modules/hadoop/id_rsa',
    mode => '400',
    require => File['/home/hadoop/.ssh'],
  }

  file { '/home/hadoop/.ssh/authorized_keys':
    ensure => present,
    source => 'puppet:///modules/hadoop/id_rsa.pub',
    mode => '600',
    require => File['/home/hadoop/.ssh'],
  }

  file { '/home/hadoop/.ssh/config':
    ensure => present,
    source => 'puppet:///modules/hadoop/ssh_config',
    mode => '600',
    require => File['/home/hadoop/.ssh'],
  }

  file { '/opt':
    ensure => directory,
    mode => 777,
    owner => 'root',
  }

  apt::ppa { 'ppa:webupd8team/java': }

  exec { 'echo debconf shared/accepted-oracle-license-v1-1 select true |
            sudo debconf-set-selections;
          echo debconf shared/accepted-oracle-license-v1-1 seen true |
            sudo debconf-set-selections':
    alias => 'accept_licence',
  }

  package { 'oracle-java7-installer':
    ensure => present,
    require => [ Apt::Ppa['ppa:webupd8team/java'], Exec['accept_licence'] ],
  }

  exec { 'download':
    command => "wget -O $download_path $remote_path",
    creates => $download_path,
  }

  exec { 'untar':
    command => "tar xzvf $download_path",
    cwd => $extract_dir,
    creates => $real_root,
    require => [ Exec['download'], User['hadoop'], File['/opt'] ],
    user => 'hadoop',
  }

  file { 'root':
    path => $hadoop::params::root,
    ensure => 'link',
    target => $real_root,
    require => Exec['untar'],
  }

  file { '/var/log/hadoop':
    ensure => directory,
  }

  file { "${hadoop::params::root}/conf/hadoop-env.sh":
    source => 'puppet:///modules/hadoop/hadoop-env.sh',
    require => File['root'],
  }

  file { "${hadoop::params::root}/conf/masters":
    content => template('hadoop/masters.erb'),
    require => File['root'],
  }

  file { "${hadoop::params::root}/conf/slaves":
    content => template('hadoop/slaves.erb'),
    require => File['root'],
  }

  file { "${hadoop::params::root}/conf/hadoop-site.xml":
    content => template('hadoop/hadoop-site.xml.erb'),
    require => File['root'],
  }

  file { "${hadoop::params::root}/conf/hdfs-site.xml":
    content => template('hadoop/hdfs-site.xml.erb'),
    require => File['root'],
  }

  file { "${hadoop::params::root}/conf/mapred-site.xml":
    content => template('hadoop/mapred-site.xml.erb'),
    require => File['root'],
  }
}
