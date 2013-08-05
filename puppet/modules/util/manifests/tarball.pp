define util::tarball (
  $remote_path,
  $download_path,
  $extract_dir,
  $extracted_dir,
  $user = 'root',
  ) {

  $cmd = "wget -O $download_path $remote_path"

  exec { $cmd:
    creates => $download_path,
  }

  exec { "tar xzvf $download_path":
    cwd => $extract_dir,
    creates => $extracted_dir,
    require => [ Exec[$cmd], File['/opt'] ],
    user => $user,
  }

}
