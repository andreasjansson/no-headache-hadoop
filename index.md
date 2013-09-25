---
layout: index
---
{% raw %}

## Introduction

This is a tutorial that describes a way to quickly setup a Hadoop cluster on cheap Amazon EC2 spot instances. We then show how to interact with the cluster by writing and running a few example Hadoop streaming jobs in Python.


## Prerequisites

You'll need very basic UNIX command line knowledge. If you're feeling a little rusty, [here's a good tutorial](http://freeengineer.org/learnUNIXin10minutes.html). The code in this tutorial has been tested on Linux, but I'd imagine it could work on OSX and maybe even Cygwin.

Most of the code is written in Python (version 2.7), so if you've never used it before, you might want to have a look at [a short tutorial](http://www.stavros.io/tutorials/python/) or [a longer one](http://docs.python.org/2.7/tutorial/).


## Initial setup

Make sure you have Python 2.7 [installed](https://wiki.python.org/moin/BeginnersGuide/Download). You'll also need [pip](http://blog.troygrosfield.com/2010/12/18/installing-easy_install-and-pip-for-python/) (recommended) or easy_install to download Python packages. The examples assume you're running `bash` as your command line.

Download [headintheclouds](https://github.com/andreasjansson/head-in-the-clouds) (a tool for managing cloud servers):

    pip install headintheclouds

If you don't have root access, and you don't have pip installed, you can install the package by typing

    export PYTHONPATH=$PYTHONPATH:$HOME/local/lib/python2.7/site-packages
    export $PATH=$PATH:$HOME/local/bin
    easy_install --prefix=$HOME/local headintheclouds

(You might want to put the `export` statements in your .bashrc or equivalent file.)

Download and unzip [no-headache-hadoop](https://github.com/andreasjansson/no-headache-hadoop) (a set of scripts that makes installing and configuring Hadoop easy):

    wget https://github.com/andreasjansson/no-headache-hadoop/archive/master.zip
    unzip master.zip

Next, we need to create an Amazon Web Services (AWS) account. Go to https://aws.amazon.com/ and click Sign Up. You'll be asked for address, phone number, credit card details, etc. When you've finished signing up, go to https://console.aws.amazon.com/iam/home?#security_credential

![security credential screen](images/security_credential.png)

Click Continue to Security Credentials. Under Access Keys, click Create New Access Key.

![new access key](images/new_access_key.png)

Click Download Key File and store the rootkey.csv file somewhere secure. If you open this file you'll see two lines, AWSAccessKeyId and AWSSecretKey. We'll use these later on.

Next, go to https://console.aws.amazon.com/ and click EC2 (Elastic Compute Cloud, Amazon's cloud server offering). In the top right corner, change the region to US East (N. Virginia).

![us east](images/us_east.png)

Under Network & Security, click Key Pairs. Click Create Key Pair and give it a name. When you click Create you'll download a .pem key file, move that file somewhere secure. You'll also need to remove the write permissions on this file, e.g.

    chmod 400 andreas-ec2.pem

Finally, we need to set a few [environment variables](http://www.cyberciti.biz/faq/set-environment-variable-linux/). You can set environment variables straight in the shell by typing `export NAME=VALUE`. The problem is that those variables will disappear next time you open a shell. To make them "stick" you can put the exports in your .bashrc file in your home directory.

 * Set `AWS_ACCESS_KEY_ID` to the AWSAccessKeyId from rootkey.csv
 * Set `AWS_SECRET_ACCESS_KEY` to the AWSSecretKey from rootkey.csv
 * Set `AWS_SSH_KEY_FILENAME` to the full path to the .pem key file, e.g. /home/andreas/secrets/andreas-ec2.pem
 * Set `AWS_KEYPAIR_NAME` to the name of the key pair, e.g. andreas-ec2

Here is an example of what your exports could look like:

    export AWS_ACCESS_KEY_ID=AKIJFKELJF98FNDNTHWQ
    export AWS_SECRET_ACCESS_KEY=9FYZlblKV3sl/7QblWbVcSQeavN64+iiyvAoXoJI
    export AWS_SSH_KEY_FILENAME=/home/andreas/secrets/andreas-ec2.pem
    export AWS_KEYPAIR_NAME=andreas-ec2

To manage our Hadoop cluster from the command line we'll use the no-headache-hadoop package we downloaded earlier. no-headache-hadoop is built on top of [fabric](http://docs.fabfile.org/), a tool written in Python for interacting with remote servers. All fabric commands, or _tasks_, are executed on the command line by typing `fab ` followed by the task name. The tasks are defined in a file called `fabfile.py`, and `fab ` must be run from the same directory as `fabfile.py`. Tasks can take arguments in the format

    fab COMMAND:X,Y,Z

Arguments can also be named

    fab COMMAND:ARG1=X,ARG2=Y,ARG3=Z

To see all the tasks provided by no-headache-hadoop, type

    fab -l

To confirm that our setup is working, `cd` to the no-headache-hadoop directory and type

    fab debug_ec2

The output should be something like

    [54.211.224.68] Executing task 'debug_ec2'
    Successfully connected to EC2


## Launching nodes

The real killer feature in AWS (at least for students and poorly funded academics) is their [spot instance](http://aws.amazon.com/ec2/spot-instances/) offering. To run EC2, Amazon needs a lot of excess capacity. Instead of letting
all that hardware sit idle, they allow people to bid on unused instances. The hourly asking price is set based on supply and demand and changes frequently. If your bid exceeds the asking price, the instances you asked for will be launched. But if the asking price increases above your bid, all instances will be terminated immediately (and you will not be charged for the partial hour). Fortunately, Hadoop offers ways to deal with this.

To see the current spot pricing, type `fab pricing`. The output looks something like:

    AMAZON EC2:

    size         compute_units  memory  recent  median  stddev  max    hourly_cost
    t1.micro                 2     0.6   0.013   0.010   0.005  0.020        0.020
    m1.small                 1     1.7   0.007   0.007   0.000  0.007        0.060
    m1.medium                2    3.75   0.013   0.013   0.000  0.013        0.120
    c1.medium                5     1.7   0.018   0.020   0.003  0.024        0.145
    m1.large                 4     7.5   0.030   0.060   0.148  0.500        0.240
    m2.xlarge              6.5    17.1   0.035   0.160   0.186  0.447        0.410
    m1.xlarge                8      15   0.052   0.054   0.020  0.200        0.480
    m3.xlarge               13      15   0.058   0.058   0.000  0.058        0.500
    c1.xlarge               20       7   0.070   0.070   0.000  0.070        0.580
    m2.2xlarge              13    34.2   0.070   0.070   0.000  0.070        0.820
    m3.2xlarge              26      30   0.115   0.115   0.040  0.200        1.000
    cc1.4xlarge           33.5      23   1.668   1.668   0.000  1.668        1.300
    m2.4xlarge              26    68.4   0.400   0.280   0.545  1.800        1.640
    cg1.4xlarge           33.5      22   2.100   2.100   0.775  2.100        2.100
    cc2.8xlarge             88    60.5   0.270   0.270   0.000  0.270        2.400
    cr1.8xlarge             88   244.0   0.343   0.343   0.083  0.510        3.500

`size` is the name Amazon gives instance types, `compute units` roughly correspond to CPUs, `memory` is the amount of RAM in GB. `recent` is the most recent spot price, `median`, `stddev` and `max` show the spot pricing over the past 24 hours. `hourly_cost` is the normal pay-as-you-go pricing. Looking at this table we see that spot instances are almost 10 times cheaper than normal instances.

To create new EC2 spot instances, type

    fab ec2.spot:ROLE,SIZE,PRICE,COUNT

where ROLE is a name we give the node, e.g. "slave"; SIZE is the instance size, e.g. "cc2.8xlarge"; PRICE is our bid, e.g. 0.28; COUNT is the number of nodes we want to launch (default 1).

To create normal ec2 instances, type

    fab ec2.create:ROLE,SIZE,COUNT

For this tutorial we'll create 10 worker nodes (slaves), one master, and one monitoring server. To keep costs down we'll make them all m1.medium instances with 3.75 GB memory and 2 [compute units](http://aws.amazon.com/ec2/faqs/#What_is_an_EC2_Compute_Unit_and_why_did_you_introduce_it). Currently, the price is $0.013/hour, and it's been constant for the past 24 hours, so it's probably safe to bid $0.015 (we'll only pay the asking price, even if our bid is higher).

The commands below will create 12 new servers, so **you will be charged _real money_ from this point on**.

    fab ec2.spot:master,m1.medium,0.015 &
    fab ec2.spot:monitoring,m1.medium,0.015 &
    fab ec2.spot:slave,m1.medium,0.015,10 &

(The ampersands at the end runs the command in the background so we create the instances in parallel.)

Side note: For new users, Amazon limits the number of instances to 20. You probably want to increase that to at least 50, using the form at https://aws.amazon.com/contact-us/ec2-request/

Once the requests have been fulfilled, we can type

`fab nodes`

which will list all instances managed by no-headache-hadoop, something like this:

    AMAZON EC2:

    name        size       ip_address      private_dns_name                status      launch_time              
    monitoring  m1.medium  54.237.35.79    ip-10-29-176-214.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.226.85.138   ip-10-182-130-122.ec2.internal  running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.226.136.131  ip-10-170-46-227.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  107.22.123.120  ip-10-169-14-198.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.221.78.152   ip-10-234-18-145.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.221.62.203   ip-10-158-92-242.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  107.21.175.247  ip-10-181-198-250.ec2.internal  running     2013-09-24 12:22:20+01:00
    master      m1.medium  54.234.195.161  ip-10-235-19-231.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.242.75.141   ip-10-181-159-97.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.226.27.0     ip-10-28-173-3.ec2.internal     running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.226.186.225  ip-10-235-28-235.ec2.internal   running     2013-09-24 12:22:20+01:00
    slave       m1.medium  54.227.34.142   ip-10-232-73-177.ec2.internal   running     2013-09-24 12:22:20+01:00

If you go to the web console at https://console.aws.amazon.com/ec2 you should see all instance names prefixed by "NHH-". This is a namespacing scheme to avoid no-headache-hadoop interfering with other instances you might have in your EC2 account. (If some of the instances are not prefixed with "NHH-" and you haven't created them outside of no-headache-hadoop, something has probably gone wrong and you should terminate those instances through the web interface to avoid wasting money.)

![instances](images/instances.png)

When you're done with our instances you **must** remember to terminate them using

    fab terminate

In order to access the servers we need to open up the EC2 firewall on the SSH port (22). We do that by typing

    fab ec2.firewall:open=22

While we're at it, let's open some other ports we'll use later on:

    fab ec2.firewall:open=80
    fab ec2.firewall:open=443
    fab ec2.firewall:open=50030
    fab ec2.firewall:open=50060

(80 is HTTP, 443 is HTTPS, 50030 and 50060 are used by the Hadoop web interface.)


## Installing the software

In the no-headache-hadoop repository, there is a folder called "puppet". It contains all the [puppet](http://docs.puppetlabs.com/) [manifests](http://docs.puppetlabs.com/learning/manifests.html#manifests) needed to install and configure Hadoop.

To install Hadoop on the servers we launched in the previous section, type

    fab build

This command will SSH into each of the servers in parallel, and install all the required software automatically. What software to install is determined by the role of the individual server.

Expect this step to take a few minutes and don't be surprised if some instances take longer than others to finish installing. If it appears to hang, you can kill the script (Ctrl-C) and try again.


## Hadoop overview

Before we move on to the example, it's probably good to look at what Hadoop actually is. This will just be a short overview, for a longer introduction to Hadoop, see http://developer.yahoo.com/hadoop/tutorial/. For the theoretical underpinnings, see [Google's original MapReduce paper](http://static.googleusercontent.com/external_content/untrusted_dlcp/research.google.com/en//archive/mapreduce-osdi04.pdf).

At the core of Hadoop is the [Hadoop Distributed File System](http://hadoop.apache.org/docs/stable/hdfs_design.html) (HDFS), a fault-tolerant, scalable file system optimised for few writes, many reads, and large files. Files are stored in 64MB blocks across multiple [data nodes](http://wiki.apache.org/hadoop/DataNode), with each block stored in several (3 by default) copies for redundancy. The [name node](http://wiki.apache.org/hadoop/NameNode) keeps an index of which block belonging to which file is stored on which server.

![hadoop overview](http://4.bp.blogspot.com/-P4_J98NDEUc/UJ-UqQ_tFCI/AAAAAAAAAqk/i_dAvUZlOx0/s1600/Data%2BNode-1.jpg)

The input to a Hadoop job is usually one or a few very large tab-separated files that are processed sequentially, line by line. The [job tracker](http://wiki.apache.org/hadoop/JobTracker) splits and distributes the input to many [task tracker](http://wiki.apache.org/hadoop/TaskTracker) servers. The job tracker manages everything around the execution of jobs, e.g. taking failed task trackers out of the pool, combining results, etc.

A Hadoop job usually has two stages: map and reduce. The mapper transforms each input record to one (or sometimes more than one) intermediate record, in the format (key, output). These intermediates are then grouped by key, sorted, and fed to the reducer, that combines them into a single (or a few) outputs.

In our setup we run the name node and job tracker on the same master instance, and each slave runs both a data node and a task tracker. This is deliberate, the job tracker actually attempts to schedule tasks to the same machine that stores the data it will operate on.

Before we can start the cluster we need to format HDFS

    fab format

Now we can start the cluster using

    fab start

## Hadoop streaming

Hadoop is written in Java, and you used to have to write map/reduce jobs in Java too. Fortunately, nowadays Hadoop has a tool called [Hadoop streaming](http://hadoop.apache.org/docs/stable/streaming.html) that allows you to write Hadoop jobs in virtually any language. The streaming job reads input lines from stdin, processes the input, and writes the output to stdout.

A nice side effect of this is that we can test streaming jobs locally on the command line before we run them on the cluster:

    cat input | ./mapper | sort | ./reducer


## Monitoring servers

The monitoring server we created earlier is running [Graphite](http://graphite.wikidot.com/), and the master and slave nodes all send it system stats using [collectd](http://collectd.org/).

The output of `fab nodes` gives us the external IP for each server. In the example above, the monitoring server is at 54.237.35.79. If enter that in a browser, we get something that looks like this:

![graphite](images/graphite.png)

(Note that this can take quite a while to load the first time, since we're running on relatively weak m1.medium machines.)

In the pane on the left we can navigate Graphite -> collectd -> [server private DNS name] -> [metric group] -> [metric name].

![graphite metric](images/graphite_metric.png)

The most important metric to keep an eye on is memory -> memory-used. Once that starts climbing towards 3GB, we are in trouble.


## Example application

Now that we have our cluster built and configured, we can start doing some actual work on it. In this example we'll [mine frequent itemsets](http://en.wikipedia.org/wiki/Association_rule_learning) of artists in the [lastfm360k](http://mtg.upf.edu/node/1671) dataset, using a [parallel version of FP-growth](http://infolab.stanford.edu/~echang/recsys08-69.pdf).


### Algorithm overview

In frequent itemset mining we aim to find subsets of items that occur in many transactions. The classic example is market basket analysis, where we want to find products that are frequently bought together. In this example we want to find sets of artists that occur in many people's Last.fm listening histories. The output will be a number of sets of artists, e.g.

    {{Metallica, Pantera, Iron Maiden},
     {DJ Slugo, Drexciya},
     {Tom Waits, Leonard Cohen, Neil Young, Ron Sexsmith}}

This could them be used in a recommendation system, e.g. "You like Metallica and Iron Maiden, so you'll probably also like Pantera".

We will use a version of the [FP-growth algorithm](http://en.wikipedia.org/wiki/Association_rule_learning#FP-growth_algorithm) that was designed as a five of map/reduce jobs.

The input data is in the format

    user id, artist id, artist name, play count

but we need it to be in the format

    user id, listening history

where the listening history is a set of artist names {artist1, artist2, artist3, ...}. The first map/reduce step is to transform the input to our format, saving the output in a file that we'll use as input to subsequent steps.

After that we'll count the number of occurrences, or _support_, of each artist in the entire dataset.

The third step is to split the set of artists up into a number of _shards_, by assigning a shard number to each artist. For example, if the artists are

    {A, B, C, D}

We might have artist shards like

    {A => 1, B => 1, C => 2, D => 2}

In the fourth step we compute the actual frequent itemsets. The trick here is to transform the data in a way that makes it possible to compute frequent itemsets in parallel. It turns out that we can do this by outputting each history record a number of times, once for each artist shard that appear in the history, along with the shard number.

Assume we're using the example artists shards from before, and we have the histories

    {{A, B}, {A, B, C}, {B, D}, {C, D}}

The output will be

    ({A, B}, 1)
    ({A, B, C}, 1)
    ({A, B, C}, 2)
    ({B, D}, 1)
    ({B, D}, 2)
    ({C, D}, 2)

The clever thing is that the history tuples can mined for frequent itemsets in isolation, since each artist shard has all of the listening histories that artist appears in. The speedup is almost linear with the number of added servers. The actual mining is done using traditional FP-growth.

The final step is to deduplicate the output from the FP-growth step.

To download and unzip the Python implementation we'll use in the examples below, type 

    wget https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/archive/master.zip
    unzip master.zip


### Downloading the dataset

We'll start off by downloading the dataset to the cluster itself. First we log in to the master node:

    fab -R master ssh

The `-R` tells fabric to only apply the command to nodes with a certain role, in this case `master`.

To do anything Hadoop-related on the server, we need to change user to hadoop:

    sudo su - hadoop

Once we're logged in we download and unpack the data using

    wget http://mtg.upf.edu/static/datasets/last.fm/lastfm-dataset-360K.tar.gz
    tar xzvf lastfm-dataset-360K.tar.gz

The files are in tsv format so we can import them straight into HDFS. We will use usersha1-artmbid-artname-plays.tsv which has 17 million records for 360,000 users, where a record consists of (user id, artist id, artist name, play count). If we look at the first few records we get an idea of what we're dealing with.

    head -n5 lastfm-dataset-360K/usersha1-artmbid-artname-plays.tsv

outputs

    00000c289a1829a808ac09c00daf10bc3c4e223b        3bd73256-3905-4f3a-97e2-8b341527f805    betty blowtorch 2137
    00000c289a1829a808ac09c00daf10bc3c4e223b        f2fb0ff0-5679-42ec-a55c-15109ce6e320    die Ärzte       1099
    00000c289a1829a808ac09c00daf10bc3c4e223b        b3ae82c2-e60b-4551-a76d-6620f1b456aa    melissa etheridge       897
    00000c289a1829a808ac09c00daf10bc3c4e223b        3d6bbeb7-f90e-4d10-b440-e153c0d10b53    elvenking       717
    00000c289a1829a808ac09c00daf10bc3c4e223b        bbd2ffd7-17f4-4506-8572-c1ea58c3f9a8    juliette & the licks    706

To import into HDFS, type

    hadoop dfs -copyFromLocal lastfm-dataset-360K/usersha1-artmbid-artname-plays.tsv /hadoop/lastfm-plays.tsv

This will copy the file to /hadoop/lastfm-plays.tsv in HDFS. We can browse HDFS using

    hadoop dfs -ls /
    hadoop dfs -ls /hadoop
    # etc.

For testing purposes we can download and unzip the dataset to our local machine using the same commands.


### Step 1/5: Preprocessing

As a first step we transform the data so that each line is in the format (user id, list of artists). The [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/preprocess/mapper.py) simply takes the input line and outputs (user id, artist name). The [reducer](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/preprocess/reducer.py) then reads the input lines that have been sorted in Hadoop streaming by user id, and keeps the artists in memory. When the user id changes or we reach the end of the file, we output the old user id along with all the artists we've collected. Note that this would not work if the records hadn't been sorted before the reduce step.

If we have downloaded the data to our local computer as well as to the master node, we can test the job locally:

    head -n1000 /path/to/lastfm-dataset-360K/usersha1-artmbid-artname-plays.tsv \
        | /path/to/pfp_lastfm360k/preprocess/mapper.py \
        | sort \
        | /path/to/pfp_lastfm360k/preprocess/reducer.py

This will output something like

    00000c289a1829a808ac09c00daf10bc3c4e223b        juliette & the licks    magica  dropkick murphys        edguy   red hot chili peppers       walls of jericho        the wallflowers jack off jill   the murmurs     the who maximum the hormone     judas priest    girlschool  le tigre        melissa etheridge       sandra nasic    bif naked       die Ärzte       the butchies    sleater-kinney  john mayer  letzte instanz  elvenking       london after midnight   tanzwut disciple        betty   team dresch     rob zombie      the rolling stones  lunachicks      mutyumu the bosshoss    jack johnson    the black dahlia murder rasputina       guano apes      babes in toyland    blue Öyster cult        horrorpops      goldfrapp       the killers     all:my:faults   l7      eluveitie       betty blowtorch     little big town schandmaul      all ends
    00001411dc427966b17297bf4d69e7e193135d89        simian mobile disco     arcade fire     the wombats     uffie   queen   ai aso  the fiery furnaces  death cab for cutie     have heart      nujabes the most serene republic        built to spill  patrick wolf    mstrkrft    the strokes     broken social scene     the last shadow puppets the secret handshake    the honorary title      little dragon       coldplay        stars   boris with michio kurihara      cancer bats     the microphones boris   animal collective       death from above 1979       heavy heavy low low     the libertines  m.i.a.  mgmt    deerhoof        michio kurihara okkervil river  owl city    breathe carolina        luminous orange coaltar of the deepers  polar bear club bright eyes     jim sturgess    hadouken!  digitalism       the album leaf  the rocket summer       arctic monkeys  fear before the march of flames hot hot heat    boris with merzbow  boys noize
    00004d2ac9316e22dc007ab2243d6fcb239e707d        castanets       baby dee        flairck andrew liles    the revolutionary army of the infant jesus  marc almond     the legendary pink dots 16 horsepower   frank london    charalambides   björk   amanda rogers   nalle       the one ensemble        current 93      carter tutti    jack rose       festival        pelt    jocelyn pook    antony and the johnsons     nurse with wound        john jacob niles        fovea hex       bill fay        michael gira    nick cave & the bad seeds   ane brun        einstürzende neubauten  larkin grimm    six organs of admittance        mariee sioux    soisong a hawk and a hacksaw        lux interna     jean parlette   coil    ulver   ghq     angels of light daniel higgs    matmos  orion rigel dommissea silver mt. zion       fern knight     marissa nadler
    [etc.]

To run streaming jobs in the cluster we use

    fab streaming:INPUT_PATH,OUTPUT_PATH,MAPPER,REDUCER,NMAPPERS,NREDUCERS

where
 * INPUT\_PATH is the HDFS path to the data we'll use as input to the job (accepts asterisk wildcards)
 * OUTPUT\_PATH is the HDFS path where we'll store the output
 * MAPPER is the local path to the mapper script
 * REDUCER is the local path to the reducer script (optional, if omitted we will store the map output in OUTPUT\_PATH)
 * NMAPPERES is the number of mappers to run (optional, if omitted Hadoop will choose a "reasonable" number, usually 2 mappers/task tracker)
 * NREDUCERS is the number of reducers to run (optional, usually 2 per task tracker if omitted)

We'll run the preprocess job as follows

    fab streaming:/hadoop/lastfm-plays.tsv,/hadoop/lastfm/preprocessed,/path/to/pfp_lastfm360k/preprocess/mapper.py,/path/to/pfp_lastfm360k/preprocess/reducer.py,20,20

This will take input from /hadoop/lastfm-plays.tsv and place the output in the HDFS directory /hadoop/lastfm/preprocessed, running 20 mappers and 20 reducers. The output should look like

    [54.234.195.161] Executing task 'streaming'
    [54.234.195.161] sudo: mkdir "/opt/streaming" || true
    [54.234.195.161] put: /home/andreas/projects/pfp_lastfm360k/preprocess/mapper.py -> /opt/streaming/mapper.py
    [54.234.195.161] put: /home/andreas/projects/pfp_lastfm360k/preprocess/reducer.py -> /opt/streaming/reducer.py
    [54.234.195.161] sudo: /opt/hadoop/bin/hadoop jar /opt/hadoop/contrib/streaming/hadoop-streaming-1.2.1.jar -D mapred.map.tasks=20 -D mapred.reduce.tasks=20 -input "/hadoop/lastfm-plays.tsv" -output "/hadoop/lastfm/preprocessed" -mapper "/opt/streaming/mapper.py " -file "/opt/streaming/mapper.py" -reducer "/opt/streaming/reducer.py " -file "/opt/streaming/reducer.py"
    [54.234.195.161] out: packageJobJar: [/opt/streaming/mapper.py, /opt/streaming/reducer.py, /tmp/hadoop/hadoop-unjar847809189279407926/] [] /tmp/streamjob3638713451144539867.jar tmpDir=null
    [54.234.195.161] out: 13/09/24 12:01:54 INFO util.NativeCodeLoader: Loaded the native-hadoop library
    [54.234.195.161] out: 13/09/24 12:01:54 WARN snappy.LoadSnappy: Snappy native library not loaded
    [54.234.195.161] out: 13/09/24 12:01:54 INFO mapred.FileInputFormat: Total input paths to process : 1
    [54.234.195.161] out: 13/09/24 12:01:57 INFO streaming.StreamJob: getLocalDirs(): [/tmp/hadoop/mapred/local]
    [54.234.195.161] out: 13/09/24 12:01:57 INFO streaming.StreamJob: Running job: job_201309241156_0001
    [54.234.195.161] out: 13/09/24 12:01:57 INFO streaming.StreamJob: To kill this job, run:
    [54.234.195.161] out: 13/09/24 12:01:57 INFO streaming.StreamJob: /opt/hadoop-1.2.1/libexec/../bin/hadoop job  -Dmapred.job.tracker=ec2-54-234-195-161.compute-1.amazonaws.com:9001 -kill job_201309241156_0001
    [54.234.195.161] out: 13/09/24 12:01:57 INFO streaming.StreamJob: Tracking URL: http://ip-10-235-19-231.ec2.internal:50030/jobdetails.jsp?jobid=job_201309241156_0001
    [54.234.195.161] out: 13/09/24 12:01:58 INFO streaming.StreamJob:  map 0%  reduce 0%
    [54.234.195.161] out:

Note the Tracking URL, `http://ip-10-235-19-231.ec2.internal:50030/jobdetails.jsp?jobid=job_201309241156_0001`. That is a link to the web interface where you can track progress of the job. Unfortunately, due to a [bug](https://issues.apache.org/jira/browse/HADOOP-2776), Hadoop exposes private DNS names rather than public IPs. Looking in fab nodes, we see that the master node public IP is 54.234.195.161, so we just replace `ip-10-235-19-231.ec2.internal` with `54.234.195.161`, and the final URL becomes `http://54.234.195.161:50030/jobdetails.jsp?jobid=job_201309241156_0001`. Going there in a browser shows us the job tracking page:

![jobtracker](images/jobtracker.png)

When the job is finished, the web interface looks like this

![jobtracker](images/jobtracker_complete.png)

Here you see that the mapper output ~17 million records, and the reducer output ~360,000 records. This is exactly what we'd expect from the proprocessing step.

For convenience no-headache-hadoop has a couple of commands for looking into HDFS without having to log in to the master node. To look at the output, type

    fab ls:/hadoop/lastfm/preprocessed

You should see something like

    $ fab ls:/hadoop/lastfm/preprocessed
    [50.19.146.217] Executing task 'ls'
    [50.19.146.217] sudo: /opt/hadoop/bin/hadoop dfs -ls "/hadoop/lastfm/preprocessed"
    [50.19.146.217] out: Found 22 items
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup          0 2013-08-06 10:00 /hadoop/lastfm/preprocessed/_SUCCESS
    [50.19.146.217] out: drwxr-xr-x   - hadoop supergroup          0 2013-08-06 09:59 /hadoop/lastfm/preprocessed/_logs
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11614189 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00000
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11915961 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00001
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11737087 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00002
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11743847 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00003
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11809913 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00004
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11790278 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00005
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11804936 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00006
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11761531 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00007
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11869207 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00008
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11802235 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00009
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11715585 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00010
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11775893 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00011
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11911725 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00012
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11738669 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00013
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11903552 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00014
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11860723 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00015
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11910172 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00016
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11906049 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00017
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11597255 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00018
    [50.19.146.217] out: -rw-r--r--   3 hadoop supergroup   11732784 2013-08-06 10:00 /hadoop/lastfm/preprocessed/part-00019
    [50.19.146.217] out:

Note that there is one "part-" file per reducer. We can look at the end of the first part by typing

    fab tail:/hadoop/lastfm/preprocessed/part-00000

Which will output

    [50.19.146.217] Executing task 'tail'
    [50.19.146.217] sudo: /opt/hadoop/bin/hadoop dfs -tail "/hadoop/lastfm/preprocessed/part-00000"
    [50.19.146.217] out: e rolling stones   los bunkers     la mano ajena   guns n' roses   fernando ubiergo        "weird al" yankovicnirvana  héroes del silencio     paul carrack    soda stereo     ac/dc   rush    the smashing pumpkins   the doors       andrés calamaro     rata blanca     avantasia       the cure        slayer  jumbo   sonata arctica  los fabulosos cadillacs
    [50.19.146.217] out: fff551b945c9489b11dcc1c46c9d7382879e413d   kasabian        the cribs       the beatles     editors the flaming lips    the pigeon detectives   embrace snow patrol     the who sigur rós       death cab for cutie     radiohead       minus the bear      los auténticos decadentes       the rakes       the format      eels    röyksopp        the kooks       jamie cullum    portishead  belle and sebastian     attaque 77      coldplay        los fabulosos cadillacs the sunshine underground        the wombatseight legs       maxïmo park     blur    muse    jack's mannequin        siempre me dejas        taking back sunday      oasis   pearl jam   the enemy       stereophonics   travis  the reindeer section    the postal service      athlete the clash       kashmir mewthe bouncing souls       andrés calamaro badly drawn boy jamiroquai      manic street preachers  kings of convenience    friendly fires      doves
    [50.19.146.217] out: 

### Step 2/5: Counting

Next we'll count the support of each artist. As input to this job we'll take the preprocessed output from the previous job. The [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/count/mapper.py) simply emits a `1` for each artist in each listening history. The [reducer](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/count/reducer.py) sums the counts for each artist. We also prune the result set to remove any artists with support less than 500, so that the following steps will be faster.

To run this job, we type

    fab streaming:/hadoop/lastfm/preprocessed/part-*,/hadoop/lastfm/counted,/path/to/pfp_lastfm360k/count/mapper.py,/path/to/projects/pfp_lastfm360k/count/reducer.py,20,20

This will output tuples in the form (artist name, count).

### Step 3/5: Sharding artists

We'll shard the artists into 1000 groups. The input to this step is the artist counts from the previous step. The [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/group/mapper.py) reads a row of (artist, count) and outputs (shard number, artist:count), where shard number is a random integer 0 <= x <= 99. The [reducer](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/group/reducer.py) groups the records by shard number into (shard number, artist1:count1, artist2:count2, ...).

Run the job with

    fab streaming:/hadoop/lastfm/counted/part-*,/hadoop/lastfm/grouped,/path/to/pfp_lastfm360k/group/mapper.py,/path/to/pfp_lastfm360k/group/reducer.py,20,20

### Step 4/5: FP-growth

Here's where it gets interesting. The input is the preprocessed list of (user, listening history) records from the first step. However, we also need the sharded artist list from step 3. The problem is that Hadoop has output as many files as there were reducers. We'll need a way to combine those output files into a single file. To do this we'll need to log in the master node again

    fab -R master ssh

Once we're logged in, become the hadoop user

    sudo su - hadoop

Next, we'll use [hadoop dfs -cat](http://hadoop.apache.org/docs/stable/file_system_shell.html#cat) to output the contents of all the sharded outputs. We'll pipe that into [hadoop dfs -put](http://hadoop.apache.org/docs/stable/file_system_shell.html#put) which will write a new file to HDFS.

    hadoop dfs -cat /hadoop/lastfm/grouped/part-* | hadoop dfs -put - /hadoop/lastfm/groups.tsv

To confirm that it worked, we'll count the lines of the new file

    hadoop dfs -cat /hadoop/lastfm/groups.tsv | wc -l

This should output `100`.

The [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/fpgrowth/mapper.py) for this job is more complicated than the ones we've seen before. First we read list of sharded artist groups straight from HDFS (we provide the path to groups.tsv as a command line argument to the mapper). We then output the set of artists in the record once for each unique artist shard number (with a sublist optimisation, described in [the paper](http://infolab.stanford.edu/~echang/recsys08-69.pdf)). The output is in the form (shard number, artist1, artist2, ...).

The [reducer](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/fpgrowth/reducer.py) is even more complicated, but you don't need to understand the exact details of what it's doing for this tutorial (unless you want to). For each artist shard, we compute the frequent itemsets (with a minimum support threshold of 500) and output them in serialized [JSON](http://www.json.org/) format. When the data gets sufficiently complicated, it is often useful to use a more expressive format than tab-separated strings used by default by Hadoop. However, since a JSON object is itself a string, we can still use it as a value in Hadoop streaming.

Notice that the key we output is the string `_` (underscore).This is an idiom for when we don't need a key. In this case, all we need are the patterns themselves.

So to launch this behemoth of a map/reduce job, type

    fab streaming:/hadoop/lastfm/preprocessed/part-*,/hadoop/lastfm/mined,"/path/to/pfp_lastfm360k/fpgrowth/mapper.py hdfs:///hadoop/lastfm/groups.tsv",/path/to/projects/pfp_lastfm360k/fpgrowth/reducer.py,20,10

Note that the mapper takes hdfs:///hadoop/lastfm/groups.tsv as an argument.

This job takes longer to run than the other jobs, simply because it's doing a lot more work. To get a sense of what's happening, open the job tracker interface and the monitoring server Graphite interface in a browser. The memory usage is especially interesting. Here is a screenshot of the memory consumption on a slave node while running the reducer

![fpgrowth memory](images/fpgrowth_memory.png)

(To see the output stacked, click Graph Options -> Area Mode -> Stacked. To select a specific time range, click the white-ish icon with a green arrow next to the thing that sort of looks like a calendar. Good web developers aren't always good designers...)

To follow progress in the Hadoop web interface, have a look at the Reduce input records vs. Map output records.

![reduce progress](images/reduce_progress.png)

Here the job has been running for 29 minutes and processed 6.3M out of 12.3M records, so we could expect the job to run for around about an hour.

### Step 5/5: Aggregating results

The output of step 4 is frequent itemsets for all artist shards. Because we send each listening histories to many shards, there will be a lot of duplicate itemsets. In the [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/aggregate/mapper.py) we output each itemset once for each artist in the itemset. The [reducer](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/aggregate/reducer.py) then outputs the unique patterns for each artist.

To run the job

    fab streaming:/hadoop/lastfm/mined/part*,/hadoop/lastfm/aggregated,/path/to/pfp_lastfm360k/aggregate/mapper.py,/path/to/pfp_lastfm360k/aggregate/reducer.py,20,20

We now have the final output, 20 files in the format `(artist, frequent itemset JSON)`. To get them out of Hadoop we can use the no-headache-hadoop task `hdfs_download`

    fab hdfs_download:/hadoop/lastfm/aggregated,aggregated.tsv

This will pull the entire /hadoop/lastfm/aggregated directory out of HDFS using [getmerge](http://hadoop.apache.org/docs/stable/file_system_shell.html#getmerge), and then download the combined file.

If we look in the file

    head aggregated.tsv

we should see something like



To save time (and money) we're pruning heavily, so we have only extracted 2621 itemsets from the 360,000 listening histories. If we set `MIN_SUPPORT` lower than 500 we would get more useful data back.


## Writing your own jobs

Now that you've seen the basics of Hadoop in action, you might want to write your own Hadoop streaming jobs. As long as you do it in Python, you should be able to follow the same approach as we've done here. If you need additional Python packages, add them to [puppet/modules/python/manifests/defaultpackages.pp](https://github.com/andreasjansson/no-headache-hadoop/blob/master/puppet/modules/python/manifests/defaultpackages.pp) in your no-headache-hadoop directory, and rebuild (`fab build`). If you're planning on writing jobs in other languages, you probably want to read up on Puppet, add a couple of manifests, and rebuild.

Once you're starting to customize no-headache-hadoop it's a probably a good idea to [fork(]https://help.github.com/articles/fork-a-repo) the [repository](https://github.com/andreasjansson/no-headache-hadoop).

While you're developing, first test the job locally to spot any obvious bugs. Debugging jobs running on Hadoop is trickier, but there are a few things you can do. Keep an eye on failed jobs count in the Hadoop web console.

![failed jobs](images/failed_jobs.png)

If you click the failed number you see a screen like this

![fail stats](images/fail_stats.png)

The Error field doesn't make much sense since we're using Hadoop streaming. However, if we click the Logs -> All link in the rightmost column (and \*ugh\* change the url from ip-XX-XX-XX-XX.ec2.internal to the public IP), we see the actual stderr.

![error log](images/error_log.png)

In this job we have a Python error, that I probably would have caught if I hadn't been lazy and run the job without testing locally first.

Hadoop also provides very [basic logging](http://hadoop.apache.org/docs/r0.18.3/streaming.html#How+do+I+update+counters+in+streaming+applications%3F) by writing lines to stderr in the format

    reporter:counter:GROUP,COUNTER,AMOUNT

In the [mapper](https://github.com/andreasjansson/parallel-frequent-itemset-mining-lastfm360k/blob/master/aggregate/mapper.py) from step 5 there is an example of this. Counters show up in the Hadoop job console.

Here are some other random things to read:

 * http://www.michael-noll.com/tutorials/writing-an-hadoop-mapreduce-program-in-python/
 * http://whyjava.wordpress.com/2011/08/04/how-i-explained-mapreduce-to-my-wife/
 * http://hadoop.apache.org/docs/stable/mapred_tutorial.html
 * http://mahout.apache.org/
 * http://pig.apache.org/
 * http://www.quora.com/What-are-some-promising-open-source-alternatives-to-Hadoop-MapReduce-for-map-reduce
 * http://storm-project.net/
 * http://spark.incubator.apache.org/
 * http://star.mit.edu/cluster/

----

![dilbert](images/dilbert.gif)

{% endraw %}
