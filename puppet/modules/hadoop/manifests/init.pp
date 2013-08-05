class hadoop {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }
  File { owner => 'hadoop', }

  $remote_path = 'http://apache.mirror.anlx.net/hadoop/common/hadoop-1.2.1/hadoop-1.2.1.tar.gz'
  $download_path = '/tmp/hadoop-1.2.1.tar.gz'
  $extract_dir = '/opt'
  $real_root = '/opt/hadoop-1.2.1'
  $root = '/opt/hadoop'

  user { 'hadoop':
    ensure => present,
    shell => '/bin/bash',
    home => '/home/hadoop',
  }

  file { '/home/hadoop':
    ensure => directory,
  }

  file { '/mnt':
    ensure => directory,
  }

  file { '/mnt/lost+found':
    ensure => absent,
    force => true,
  }

  if $cloud == 'Amazon EC2' {
    file { '/home/hadoop/dfs':
      ensure => 'link',
      target => '/mnt',
      require => File['/home/hadoop'],
    }
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

  util::tarball { 'hadoop':
    remote_path => $remote_path,
    download_path => $download_path,
    extract_dir => $extract_dir,
    extracted_dir => $real_root,
    user => 'hadoop',
    require => User['hadoop'],
  }

  file { $root:
    ensure => 'link',
    target => $real_root,
    require => Util::Tarball['hadoop'],
  }

  file { '/var/log/hadoop':
    ensure => directory,
  }

  file { "$root/conf/hadoop-env.sh":
    source => 'puppet:///modules/hadoop/hadoop-env.sh',
    require => File[$root],
  }

  file { "$root/conf/masters":
    content => template('hadoop/masters.erb'),
    require => File[$root],
  }

  file { "$root/conf/slaves":
    content => template('hadoop/slaves.erb'),
    require => File[$root],
  }

  file { "$root/conf/core-site.xml":
    content => template('hadoop/core-site.xml.erb'),
    require => File[$root],
  }

  file { "$root/conf/hdfs-site.xml":
    content => template('hadoop/hdfs-site.xml.erb'),
    require => File[$root],
  }

  file { "$root/conf/mapred-site.xml":
    content => template('hadoop/mapred-site.xml.erb'),
    require => File[$root],
  }

}
