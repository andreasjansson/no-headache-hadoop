import os
import uuid
from fabric.api import *
import fabric.api as fab
import urlparse
import re
import shlex

env.name_prefix = 'NHH-'

from headintheclouds.util import autodoc
try:
    from headintheclouds import ec2
except Exception:
    pass

try:
    from headintheclouds import do
except Exception:
    pass

from headintheclouds.tasks import *

@task
@parallel
def build(update=True):
    role_manifests = {
        'master': 'hadoop.pp',
        'slave': 'hadoop.pp',
        'monitoring': 'monitoring.pp'
    }

    role = env.role
    if role not in role_manifests:
        abort('%s is not in the set of recognised roles (%s)' % (role, ', '.join(role_manifests.keys())))

    puppet(role_manifests[role], update=update)
    
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
@autodoc
def put(local_path, hdfs_path):
    local_path = os.path.expanduser(local_path)
    tmp_path = '/tmp/' + os.path.basename(hdfs_path)
    fab.put(local_path, tmp_path)
    hexec('hadoop dfs -moveFromLocal "%s" "%s"' % (tmp_path, hdfs_path))

@task
@roles('master')
@autodoc
def get(hdfs_path, local_path='./', gzip=True):
    local_path = os.path.expanduser(local_path)
    basename = os.path.basename(local_path)
    if not basename:
        basename = hdfs_path.lower().strip('/').split('/')[-1]
        local_path = os.path.dirname(local_path) + '/' + basename
    tmp_path = re.sub(r'[^a-z0-9]', '-', basename)
    local_zip_path = local_path + '.tar.gz'
    tmp_zip_path = tmp_path + '.tar.gz'
    sudo('rm -rf "/tmp/%s"' % tmp_path)
    sudo('mkdir "/tmp/%s"' % tmp_path, user='hadoop', shell=False)
    hexec('hadoop dfs -get "%s" "/tmp/%s"' % (hdfs_path, tmp_path))
    sudo('cd /tmp; tar czvf "%s" "%s"' % (tmp_zip_path, tmp_path))
    fab.get('/tmp/' + tmp_zip_path, local_zip_path)
    local('tar xzvf "%s"' % (local_zip_path))

@task
@roles('master')
@autodoc
def ls(hdfs_path='/hadoop'):
    hexec('hadoop dfs -ls "%s"' % hdfs_path)

@task
@roles('master')
@autodoc
def combine(from_hdfs_path, to_hdfs_path):
    sudo('hadoop dfs -cat "%s" | hadoop dfs -put - "%s"' % (from_hdfs_path, to_hdfs_path),
         user='hadoop', shell=True)

@task
@roles('master')
@autodoc
def tail(hdfs_path):
    hexec('hadoop dfs -tail "%s"' % hdfs_path)

@task
@roles('master')
@autodoc
def streaming(input_path, output_path, mapper, reducer=None, nmappers=None, nreducers=None):
    parts = shlex.split(mapper, 1)
    mapper_command = parts[0]
    if len(parts) > 1:
        mapper_args = parts[1]
    else:
        mapper_args = ''
    mapper = os.path.expanduser(mapper_command)
    if reducer:
        parts = shlex.split(reducer, 1)
        reducer_command = parts[0]
        if len(parts) > 1:
            reducer_args = parts[1]
        else:
            reducer_args = ''
        reducer = os.path.expanduser(reducer_command)
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
    opts.append('-mapper "%s %s"' % (mapper_path, mapper_args))
    opts.append('-file "%s"' % mapper_path)

    if reducer:
        reducer_path = '%s/%s' % (dir, os.path.basename(reducer))
        fab.put(reducer, reducer_path, use_sudo=True)
        opts.append('-reducer "%s %s"' % (reducer_path, reducer_args))
        opts.append('-file "%s"' % reducer_path)

    hexec('hadoop jar /opt/hadoop/contrib/streaming/hadoop-streaming-1.2.1.jar %s' % ' '.join(opts))

@task
@roles('master')
@autodoc
def hexec(command):
    sudo('/opt/hadoop/bin/%s' % command, user='hadoop', shell=False)

