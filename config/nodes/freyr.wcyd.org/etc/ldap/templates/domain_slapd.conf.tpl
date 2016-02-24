### BEGIN <% DOMAIN %> slapd section ###
database        bdb
suffix          "<% BASE_DN %>"
checkpoint      512 30
rootdn          "cn=root,ou=Special Users,<% BASE_DN %>"
include         /etc/ldap/rootpw.conf
directory       /opt/ldap-data/<% DOMAIN %>
index objectClass       eq
index zoneName           eq
index relativeDomainName eq
index	sudoUser	eq

# <% DOMAIN %> LDAP Options
lastmod                 on
dbconfig                set_cachesize 0 2097152 0
overlay                 syncprov
syncprov-checkpoint     1000 60

<% NOT_ME %>include /etc/ldap/domains/<% DOMAIN %>_replica.conf

# <% DOMAIN %> ACL Definitions

# give ldap peers limitless searches
limits group="cn=LDAP Providers,ou=Special,<% BASE_DN %>" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
limits group="cn=LDAP Replicas,ou=Special,<% BASE_DN %>" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited

access to dn.exact="cn=LDAP Anonymous,ou=Special,<% BASE_DN %>" attrs=userPassword 
        by dn.regex="^[^,]+,ou=Hosts,<% BASE_DN %>$" read
        by self read
        by * read

access to attrs=sshPublicKey
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Administrators,ou=Special,<% BASE_DN %>" write
        by dn.regex="^[^,]+,ou=Hosts,dc=websages,dc=com$" write
        by self write
        by * read

access to attrs=sshPublicKey,maildrop,pagerEmail,userCertificate;binary
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Administrators,ou=Special,<% BASE_DN %>" write
        by self write
        by * read

access to dn.base="" by * read

access to attrs=userPassword,shadowLastChange,sshPublicKey
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Administrators,ou=Special,<% BASE_DN %>" write
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Providers,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Replicas,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Servers,ou=Special,<% BASE_DN %>" read
        by anonymous auth
        by self write
        by * none 

access to dn.subtree="ou=DNS,<% BASE_DN %>"
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Administrators,ou=Special,<% BASE_DN %>" write
        by group/groupOfUniqueNames/UniqueMember.exact="cn=DNS Administrators,ou=Special,<% BASE_DN %>" write
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Providers,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Replicas,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Servers,ou=Special,<% BASE_DN %>" read
        by dn.exact="cn=LDAP Anonymous,ou=Special,<% BASE_DN %>" read
        by users read
        by * none

access to *
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Administrators,ou=Special,<% BASE_DN %>" write
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Providers,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Replicas,ou=Special,<% BASE_DN %>" read
        by group/groupOfUniqueNames/UniqueMember.exact="cn=LDAP Servers,ou=Special,<% BASE_DN %>" read
        by dn.exact="cn=LDAP Anonymous,ou=Special,<% BASE_DN %>" read
        by users read
        by * none

### END <% DOMAIN %> slapd section ###

