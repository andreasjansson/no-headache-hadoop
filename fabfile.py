import os
from fabric.api import *

from headintheclouds import ec2
from headintheclouds import do
from headintheclouds.tasks import *

@task
@roles('master')
def format():
    hexec('hadoop namenode -format')

@task
@roles('master')
def start():
    hexec('start-all.sh')

@task
@roles('master')
def stop():
    hexec('start-all.sh')

@task
@roles('master')
def dfs_put(local_path, hdfs_path):
    local_path = os.path.expanduser(local_path)
    tmp_path = '/tmp/' + os.path.basename(hdfs_path)
    upload(local_path, tmp_path)
    hexec('hadoop dfs -moveFromLocal %s %s' % (tmp_path, hdfs_path))

@task
@roles('master')
def dfs_get(hdfs_path, local_path):
    local_path = os.path.expanduser(local_path)
    tmp_path = '/tmp/' + os.path.basename(hdfs_path)
    hexec('hadoop dfs -get %s %s' % (hdfs_path, tmp_path))
    get(tmp_path, local_path)

@task
@roles('master')
def streaming(input_path, output_path, mapper, reducer, nmappers=None):
    mapper = os.path.expanduser(mapper)
    reducer = os.path.expanduser(reducer)

    config = ' '
    if nmappers is not None:
        config = '-D mapred.map.tasks=%d' % int(nmappers)

    dir = '/opt/streaming'
    sudo('mkdir %s || true' % dir, user='hadoop', shell=False)
    mapper_path = '%s/%s' % (dir, os.path.basename(mapper))
    reducer_path = '%s/%s' % (dir, os.path.basename(reducer))
    put(mapper, mapper_path)
    put(reducer, reducer_path)

    hexec('hadoop jar /opt/hadoop/contrib/streaming/hadoop-streaming-1.1.2.jar %s -input "%s" -output "%s" -mapper "%s" -reducer "%s" -file "%s" -file "%s"' % (config, input_path, output_path, mapper_path, reducer_path, mapper_path, reducer_path))

@task
@roles('master')
def hexec(command):
    sudo('/opt/hadoop/bin/%s' % command, user='hadoop', shell=False)
