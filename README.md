### WTF is this shit?
Stuff with an asterisk we care about, just avoid the rest unless there's a compelling reason to pull it in. I'm working to excise it.
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

### Bootstrapping a host (gets masterfiles/&lt;branch&gt; deployed to ```$(sys.inputs)```)

#### Install cfengine3
```
dpkg -l | grep -q "ii  cfengine3" || (apt-get update && apt-get install -y cfengine3)
```

#### Enable the Services
```
[ ! -f /etc/default/cfengine3.dist ] && cp /etc/default/cfengine3 /etc/default/cfeninge3.dist
sed -i -e 's/RUN_CF\(.*\)=0/RUN_CF\1=1/' /etc/default/cfengine3
```

#### Remove the stuff that ships with cfengine (it's terrible.)
```
rm -fr /var/lib/cfengine3/{masterfiles,inputs}
```

#### scp your ppkey to the policy host
```
( cd /var/lib/cfengine3/ppkeys; scp localhost.pub root@odin.websages.com:/var/lib/cfengine3/ppkeys/root-$(cf-key -p localhost.pub).pub )
```

#### (Only if necessary) Add your egress IP to the [$(def.acl)](https://github.com/websages/masterfiles/blob/master/def.cf#L25-L30)
```
      "acl"     slist => {
                           "<YOUR_EGRESS_IP_HERE>/32",
                           "104.237.144.97",
                           "75.146.11.137",
                           ".*$(def.domain)",
                         },
```

#### (Optionally) Mark your host as being on a non-master branch of masterfiles
```
echo "some_feature_branch" > /var/lib/cfengine3/current_branch
```

#### Fetch and run the failsafe config
```
curl -s https://raw.githubusercontent.com/websages/masterfiles/master/failsafe.cf > /var/lib/cfengine3/inputs/failsafe.cf
cf-agent -Kvf /var/lib/cfengine3/inputs/failsafe.cf
```

### Run Cfengine
```
cf-agent -Kv
```

