#!/bin/bash -e

# This is useful so we can debug containers running inside of OpenShift that are
# failing to start properly.
if [ "$OO_PAUSE_ON_START" = "true" ] ; then
  echo
  echo "This container's startup has been paused indefinitely because OO_PAUSE_ON_START has been set."
  echo
  while sleep 10; do
    true
  done
fi

# interactive shells read .bashrc (which this script doesn't execute as) so force it
source /root/.bashrc

# Configure the container
time ansible-playbook /root/config.yml

# Configure rkhunter
echo '/usr/bin/ops-runner -f -t 600 -n monitoring.root.rkhunter.yml ansible-playbook /root/rkhunter.yml >> /var/log/rkhunter.yml.log &'
/usr/bin/ops-runner -f -t 600 -n monitoring.root.rkhunter.yml ansible-playbook /root/rkhunter.yml >> /var/log/rkhunter.yml.log &

# Send a heartbeat when the container starts up
/usr/bin/ops-metric-client --send-heartbeat

# fire off the check pmcd status script
check-pmcd-status.sh &
# fire off the pmcd script
#/usr/share/pcp/lib/pmcd start &
/root/start-pmcd.bash > /var/log/pmcd.log &

/root/autoheal-check-ovs-socket.sh &

# Run the main service of this container
echo
echo 'Starting crond'
echo '---------------'

#TODO: remove this. selinux is causing problems with crond in some clusters.
echo "Remove this: setenforce 0"
setenforce 0
#ENDTODO

exec /usr/sbin/crond -n -m off -x sch,proc,load
