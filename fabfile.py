import os
import uuid
from fabric.api import *
import fabric.api as fab
import urlparse
import re

from headintheclouds import ec2
#from headintheclouds import do
from headintheclouds.tasks import *
import headintheclouds.tasks as tasks

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
    hexec('stop-all.sh')

@task
@roles('master')
def restart():
    stop()
    start()

@task
@roles('master')
def put(local_path, hdfs_path):
    local_path = os.path.expanduser(local_path)
    tmp_path = '/tmp/' + os.path.basename(hdfs_path)
    fab.put(local_path, tmp_path)
    hexec('hadoop dfs -moveFromLocal "%s" "%s"' % (tmp_path, hdfs_path))

@task
@roles('master')
def get(hdfs_path, local_path='./'):
    local_path = os.path.expanduser(local_path)
    tmp_path = '/tmp/' + re.sub(r'[^a-z0-9]', '-', hdfs_path.lower().strip('/'))
    sudo('mkdir %s | true' % tmp_path, user='hadoop', shell=False)
    hexec('hadoop dfs -get "%s" "%s"' % (hdfs_path, tmp_path))
    fab.get(tmp_path, local_path)

@task
@roles('master')
def ls(hdfs_path='/hadoop'):
    hexec('hadoop dfs -ls "%s"' % hdfs_path)

@task
@roles('master')
def streaming(input_path, output_path, mapper, reducer=None, nmappers=None, nreducers=None):
    mapper = os.path.expanduser(mapper)
    if reducer:
        reducer = os.path.expanduser(reducer)
    else:
        nreducers = 0

    opts = []
    if nmappers is not None:
        opts.append('-D mapred.map.tasks=%d' % int(nmappers))
    if nreducers is not None:
        opts.append('-D mapred.reduce.tasks=%d' % int(nreducers))

    opts.append('-input "%s"' % input_path)
    opts.append('-output "%s"' % output_path)

    dir = '/opt/streaming'
    sudo('mkdir "%s" || true' % dir, user='hadoop', shell=False)

    mapper_path = '%s/%s' % (dir, os.path.basename(mapper))
    fab.put(mapper, mapper_path, use_sudo=True)
    opts.append('-mapper "%s"' % mapper_path)
    opts.append('-file "%s"' % mapper_path)

    if reducer:
        reducer_path = '%s/%s' % (dir, os.path.basename(reducer))
        fab.put(reducer, reducer_path, use_sudo=True)
        opts.append('-reducer "%s"' % reducer_path)
        opts.append('-file "%s"' % reducer_path)

    hexec('hadoop jar /opt/hadoop/contrib/streaming/hadoop-streaming-1.1.2.jar %s' % ' '.join(opts))

@task
@roles('master')
def hexec(command):
    sudo('/opt/hadoop/bin/%s' % command, user='hadoop', shell=False)


