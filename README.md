Just an experiment. Nothing to really see here...
```
dpkg -l | grep -q "ii  cfengine3" || (apt-get update && apt-get install -y cfengine3)
dpkg -l | grep -q "ii  git" || (apt-get update && apt-get install -y git)
[ ! -f /etc/default/cfengine3.dist ] && cp /etc/default/cfengine3 /etc/default/cfeninge3.dist
sed -i -e 's/RUN_CF\(.*\)=0/RUN_CF\1=1/' /etc/default/cfengine3
rm -fr /var/lib/cfengine3/{masterfiles,inputs}
( cd /var/lib/cfengine3/ppkeys; scp localhost.pub root@odin.websages.com:/var/lib/cfengine3/ppkeys/root-$(cf-key -p localhost.pub).pub )
# write out failsafe.cf
cf-agent -Kvf /var/lib/cfengine3/inputs/failsafe.cf
cf-agent -Kv
```
