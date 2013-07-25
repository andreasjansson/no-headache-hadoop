No Headache Hadoop
==================

A set of Fabric tasks that makes it easy to set up Hadoop
on EC2 and Digital Ocean.

Installation
------------

    pip install headintheclouds
    apt-get install puppet # or whatever package manager you use
    git clone https://github.com/andreasjansson/no-headache-hadoop.git

You will need to populate the following environment variables:

    export AWS_EC2_REGION=...
    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...
    export AWS_SSH_KEY_FILENAME=...
    export AWS_KEYPAIR_NAME=...
    export DIGITAL_OCEAN_CLIENT_ID=...
    export DIGITAL_OCEAN_API_KEY=...
    export DIGITAL_OCEAN_SSH_KEY_FILENAME=...
    export DIGITAL_OCEAN_SSH_KEY_NAME=...

These can be obtained from the AWS and Digital Ocean web interfaces. You'll need
to sign up to both services. If you only want to use one or the other, comment out
one of the lines

    from headintheclouds import ec2
    from headintheclouds import do

from `fabfile.py`.

Usage
-----

(All these commands must execute from the same directory that has fabfile.py)

To see the current instance prices:

    fab pricing

---

To create new spot instances on EC2:

    fab ec2.spot:ROLE,SIZE,PRICE,COUNT

---

To create new on-demand instances on EC2:

    fab ec2.create:ROLE,SIZE

---

To create new on-demand instances on Digital Ocean:

    fab do.create:ROLE,SIZE

---

To terminate all nodes:

    fab terminate

---

To list all nodes:

    fab nodes

---

To rename all nodes:

    fab rename:NEW_ROLE

---

To SSH into a specific node:

    fab -H IP_ADDRESS ssh

---

To rename specific nodes:

    fab -R CURRENT_ROLE rename:NEW_ROLE

or

    fab -H IP_ADDRESS rename:NEW_ROLE

**Before installing Hadoop all nodes should be named `slave`, except one which should be named `master`.**
You can do this by

    fab rename:slave
    fab -H ONE_SPECIFIC_IP_ADDRESS rename:master

---

To install Hadoop on all nodes:

    fab build:init=hadoop.pp

**The Hadoop distribution will be installed in /opt/hadoop**

---

To format the Hadoop namenode:

    fab format

---

To start Hadoop:

    fab start

---

To upload files to HDFS:

    fab dfs_put:LOCAL_PATH,REMOTE_PATH

---

To download files from HDFS:

    fab dfs_get:LOCAL_PATH,REMOTE_PATH

---

To start a streaming job:

    fab streaming:INPUT_PATH,OUTPUT_PATH,MAPPER,REDUCER

_where_
  * `INPUT_PATH` and `OUTPUT_PATH` are both HDFS paths
  * `MAPPER` and `REDUCER` are local paths

---

To execute an arbitrary Hadoop command:

    fab hexec:"COMMAND"

Notes
-----

The Fabric tasks that creates, terminates, and builds servers is in the [headintheclouds](https://github.com/andreasjansson/head-in-the-clouds) package.
