JAVA_PATH=`which java`
JAVA_PATH=`readlink -f $JAVA_PATH`
export JAVA_HOME=`dirname $JAVA_PATH`/..
export HADOOP_PREFIX='/opt/hadoop'
export PATH=$PATH:/opt/pig/bin
