#unzip the first input on second input location.
tar xf $1 -C $2
echo "$1 untared"
suffix=".tar.gz"
y=$(basename $1)
y=${y%"$suffix"}
relativePath="$2$y"
Pwd=$(pwd)
Pwd="$Pwd/$relativePath"
#configure ssh
ssh-keygen -t rsa -P ""
echo "keygen done"
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
echo "copy done"
chmod 750 ~/.ssh/authorized_keys
ssh-copy-id -i localhost;

cd $Pwd
#add in bashrc
suffix="/bin/javac"
java_home=$(readlink -f $(which javac))
java_home=${java_home%"$suffix"}
echo $java_home
#bashrcString=
bashrcString="export HADOOP_INSTALL=$Pwd \n export JAVA_HOME=$java_home \n
export PATH=\$PATH:\$HADOOP_INSTALL/bin \n
export PATH=\$PATH:\$HADOOP_INSTALL/sbin \n
export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL \n
export HADOOP_COMMON_HOME=\$HADOOP_INSTALL \n
export HADOOP_HDFS_HOME=\$HADOOP_INSTALL \n
export YARN_HOME=\$HADOOP_INSTALL"

echo -e $bashrcString >> ~/.bashrc
source ~/.bashrc
hadoopFiles="$Pwd/etc/hadoop"
hadoopEnvLoc="$hadoopFiles/hadoop-env.sh"
sed -i "s@export JAVA_HOME=\${JAVA_HOME}@export JAVA_HOME=$java_home@" $hadoopEnvLoc
echo "hadoop-env.h done"
coreSite="<property> \
<name>fs.default.name<\/name><value>hdfs:\/\/$(whoami):9000<\/value><\/property><\/configuration>"
coreSiteLoc="$hadoopFiles/core-site.xml"
sed -i "s@</configuration>@$coreSite@" $coreSiteLoc
echo "core-site.xml done"
yarnSite="<property> \
 <name>yarn.nodemanager.aux-services<\/name> \
 <value>mapreduce_shuffle<\/value> \
<\/property> \
<property> \
 <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class<\/name> \
 <value>org.apache.hadoop.mapred.ShuffleHandler<\/value> \
<\/property><\/configuration>"
yarnSiteLoc="$hadoopFiles/yarn-site.xml"
sed -i "s@</configuration>@$yarnSite@" $yarnSiteLoc
echo "yarn-site.xml done"
mv "$hadoopFiles/mapred-site.xml.template" "$hadoopFiles/mapred-site.xml"
mapredSite="<property> \
 <name>mapreduce.framework.name<\/name> \
 <value>yarn<\/value> \
<\/property><\/configuration>"
mapredSiteLoc="$hadoopFiles/mapred-site.xml"
sed -i "s@</configuration>@$mapredSite@" $mapredSiteLoc
echo "mared-site.xml done"
mkdir -p ~/mydata/hdfs/namenode
mkdir -p ~/mydata/hdfs/datanode
hdfsSite="<property> \
 <name>dfs.replication<\/name> \
 <value>1<\/value> \
<\/property> \
<property> \
 <name>dfs.datanode.data.dir<\/name> \
 <value>file:\/home\/$(whoami)\/mydata\/hdfs\/datanode<\/value> \
<\/property></configuration>"
hdfsSiteLoc="$hadoopFiles/hdfs-site.xml"
sed -i "s@</configuration>@$hdfsSite@" $hdfsSiteLoc
echo "hdfs-site done"

count=1
newPwd=${Pwd%"$y"}
for i in "$@" ; do
	if [ $count -le 2 ]
	then
		count=$((count+1))
		continue
	fi
	ssh-copy-id -i "$i"
	scp -r $Pwd $(whoami)@"$i":$newPwd
	count=$((count+1))
done

numberOfOptions="$#"
numberOfSlaves=$((numberOfOptions-2))
sed -i "s@1@$numberOfSlaves@" $hdfsSiteLoc
yarnAppendString="<property> \
                                  <name>yarn.resourcemanager.resource-tracker.address<\/name> \
                                  <value>$(whoami):8025<\/value> \
                       <\/property> \
                       <property> \
                                  <name>yarn.resourcemanager.scheduler.address<\/name> \
                                  <value>$(whoami):8030<\/value> \
                       <\/property> \
                       <property> \
                                  <name>yarn.resourcemanager.address<\/name> \
                                  <value>$(whoami):8050<\/value> \
                       <\/property><\/configuration>"
sed -i "s@</configuration>@$yarnAppendString@" $yarnSiteLoc
sed -i "s@mapreduce.framework.name@mapred.job.tracker@" $mapredSiteLoc
sed -i "s@yarn@$(whoami):54311@" $mapredSiteLoc
sed -i "s@datanode@namenode@" $hdfsSiteLoc

echo "" > "$hadoopFiles/slaves"
count=1
for i in "$@" ; do
	if [ $count -le 2 ] 
	then
		count=$((count+1))
		continue
	fi
	echo "$i" >> "$hadoopFiles/slaves"
	ssh -t "$i" "mkdir -p ~/mydata/hdfs/datanode;$(echo -e $bashrcString >> ~/.bashrc;source ~/.bashrc)"
	count=$((count+1))
done