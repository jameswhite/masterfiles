#### Bootstrapping a host (gets masterfiles/<branch> deployed to ```$(sys.inputs)```)
```
dpkg -l | grep -q "ii  cfengine3" || (apt-get update && apt-get install -y cfengine3)
dpkg -l | grep -q "ii  git" || (apt-get update && apt-get install -y git)
[ ! -f /etc/default/cfengine3.dist ] && cp /etc/default/cfengine3 /etc/default/cfeninge3.dist
sed -i -e 's/RUN_CF\(.*\)=0/RUN_CF\1=1/' /etc/default/cfengine3
rm -fr /var/lib/cfengine3/{masterfiles,inputs}
( cd /var/lib/cfengine3/ppkeys; scp localhost.pub root@odin.websages.com:/var/lib/cfengine3/ppkeys/root-$(cf-key -p localhost.pub).pub )
curl -s https://raw.githubusercontent.com/websages/masterfiles/master/failsafe.cf > /var/lib/cfengine3/inputs/failsafe.cf
cf-agent -Kvf /var/lib/cfengine3/inputs/failsafe.cf
cf-agent -Kv
```

#### WTF is this shit?
Stuff with an asterisk we care about, just avoid the rest unless there's a compelling reason to pull it in.
```
README.md* ..... You're reading it.
cfe_internal ... Some superfluous ha/hub specific things that cfengine ships.
config* ........ Configurations of hosts
controls* ...... The config files for the cf-* services.
def.cf*......... Site definitions.
failsafe.cf* ... The bootstrap file.
inventory ...... More superfluous configs that cfengine feels we need.
lib ............ 3.5/3.6 compatibility policies.
promises.cf* ... The primary configuration file (what get's sourced when not bootstrapping/failsafing/updating.)
services ....... More superfluous stuff (looks like it's used for Windows.)
sketches ....... Some new (and probably superfluous) method for writing policies.
templates ...... Primary Template dir, ignore this and use config.
update ......... Cfengine built-ins for updating using ha and hubs.
update.cf* ..... The update policy.
```
