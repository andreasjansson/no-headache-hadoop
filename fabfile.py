from headintheclouds import ec2
#from headintheclouds import do
from headintheclouds.tasks import *

from fabric.api import *

@roles('master')
def start_hadoop():
    sudo('/opt/hadoop/bin/start-all.sh', user='hadoop')

@roles('master')
def stop_hadoop():
    sudo('/opt/hadoop/bin/stop-all.sh', user='hadoop')
