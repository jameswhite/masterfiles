Just an experiment. Nothing to really see here...
```
#!/bin/bash
dpkg -l | grep -q "ii  cfengine3"
if [ $? -ne 0 ]; then
  apt-get update
  apt-get install cfengine3
fi

[ ! -f /etc/default/cfengine3.dist ] && cp /etc/default/cfengine3 /etc/default/cfengine3.dist
cat<<EOF > /etc/default/cfengine3
RUN_CFMONITORD=1
RUN_CFSERVERD=1
RUN_CFEXECD=1
CFMONITORD_ARGS=""
CFSERVERD_ARGS=""
CFEXECD_ARGS=""
EOF

[ -d   "/etc/cfengine3"            ] && mv /etc/cfengine3 /etc/cfengine3.old
[ -d   "/var/cfengine"             ] && mv /var/cfengine /var/cfengine.old
[ -h   "/var/lib/cfengine3/inputs" ] && unlink /var/lib/cfengine3/inputs
[ ! -d "/var/lib/cfengine3/inputs" ] && mkdir -p /var/lib/cfengine3/inputs
[ ! -h "/etc/cfengine3"            ] && ln -s /var/lib/cfengine3/inputs /etc/cfengine3
[ ! -h "/var/cfengine"             ] && ln -s /var/lib/cfengine3 /var/cfengine
[ -d   "/var/lib/cfengine3/bin"    ] && rm -fr /var/lib/cfengine3/bin
[ ! -h "/var/lib/cfengine3/bin"    ] && ln -s /usr/sbin /var/lib/cfengine3/bin

(
  cd /var/lib/cfengine3
  [ -d masterfiles ] && [ ! -d masterfiles.dist ] && mv masterfiles masterfiles.dist
  git clone https://github.com/websages/masterfiles
  rsync -avzP  /var/lib/cfengine3/masterfiles/ /var/lib/cfengine3/inputs/
)

cf-agent -Kv 
```
