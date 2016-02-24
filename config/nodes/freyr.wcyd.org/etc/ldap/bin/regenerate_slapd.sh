#!/bin/bash
# items specific to this host
MYHOST=$(hostname -s)
MYDOMAIN=$(dnsdomainname)
MYBASEDN="dc=$(echo ${MYDOMAIN}|sed -e 's/\./,dc=/g')"
# directories we care about
ETCLDAP="/etc/ldap"
LDAP_DOMAINS="${ETCLDAP}/domains"
LDAP_DATA="/opt/ldap-data"
TEMPLATE_DIR="/etc/ldap/templates/"
TEMPLATES="domain_replica.conf.tpl domain_slapd.conf.tpl"
for templ in $(echo ${TEMPLATES}); do 
    if [ ! -f ${TEMPLATE_DIR}/${templ} ]; then
        echo "required template [${templ}] missing. Aborting."
        exit -1;
    fi
done    

SLAPD_NEEDS_RELOADED=0;
# export DEBIAN_FRONTEND=noninteractive; dpkg -l|grep "ii *slapd" || apt-get install -y slapd

################################################################################
# query our LDAP Servers, get our naming contexts.
################################################################################
we_can_bind(){
    ldapsearch -xL \
               -b "${MYBASEDN}" \
               -D "cn=${MYHOST},ou=Hosts,${MYBASEDN}" \
               -w $(secret) \
               -s base "(cn=${MYHOST})" > /dev/null 
    return $?
}

naming_contexts(){
    CONTEXTS=$(
                ldapsearch -xL \
                           -b "" \
                           -D "cn=${MYHOST},ou=Hosts,${MYBASEDN}" \
                           -w $(secret) \
                           -s base namingcontexts |\
                    grep "^namingContexts: " | sed -e 's/^namingContexts: //'
              )
    echo ${CONTEXTS}
}

ldap_replicas_for(){
    THISBASE=$1;
    for dn in `ldapsearch -xL \
                          -b "ou=Special,${THISBASE}" \
                          -D "cn=${MYHOST},ou=Hosts,${MYBASEDN}" \
                          -w $(secret) \
                          -s sub "(cn=LDAP Replicas)" | grep "^uniqueMember: " |sed -e 's/^uniqueMember: //'`;do
       echo ${dn}| tr A-Z a-z |sed -e 's/^cn=//g' -e 's/,ou=hosts//g' -e 's/,dc=/./g'
   done
}

ldap_providers_for(){
    THISBASE=$1;
    for dn in `ldapsearch -xL \
                          -b "ou=Special,${THISBASE}" \
                          -D "cn=${MYHOST},ou=Hosts,${MYBASEDN}" \
                          -w $(secret) \
                          -s sub "(cn=LDAP Providers)" | grep "^uniqueMember: " |sed -e 's/^uniqueMember: //'`;do
       echo ${dn}| tr A-Z a-z |sed -e 's/^cn=//g' -e 's/,ou=hosts//g' -e 's/,dc=/./g'
   done
}
################################################################################
# These should be fetched from DNS, not ldap, or we can't bootstrap            # 
################################################################################

################################################################################
#                                                                              #
################################################################################

rootpw(){
     echo -n "rootpw " > ${ETCLDAP}/rootpw.conf
     echo $(secret) | slappasswd -h {SSHA} -s - >>  ${ETCLDAP}/rootpw.conf
     chown openldap:openldap ${ETCLDAP}/rootpw.conf
     chmod 400 ${ETCLDAP}/rootpw.conf
}

slapd_domains_conf(){
    slapd_domain=$1
    if [ ! -f ${ETCLDAP}/slapd_domains.conf ];then
        touch ${ETCLDAP}/slapd_domains.conf
        chown openldap:openldap ${ETCLDAP}/slapd_domains.conf
    fi
    grep "include /etc/ldap/domains/${slapd_domain}_slapd.conf" ${ETCLDAP}/slapd_domains.conf > /dev/null 2>&1|| \
        echo "include /etc/ldap/domains/${slapd_domain}_slapd.conf" >> ${ETCLDAP}/slapd_domains.conf
}

next_rid(){
    LAST_RID=$(grep "syncrepl *rid=" ${ETCLDAP}/domains/*_replica.conf 2>/dev/null|\
               sed -e 's/.*syncrepl *rid=//g' -e 's/#.*//'| \
               sort -n|\
               tail -1) 
    [ -z ${LAST_RID} ] && LAST_RID=100;
    expr ${LAST_RID} + 1
}

domain_slapd.conf(){
    NEWDOM=$1
    TYPE=$2 #provider||replica
    NEWBDN="dc=$(echo ${NEWDOM}|sed -e 's/\./,dc=/')"
    # Create our bdb dir
    if [ ! -d ${LDAP_DATA} ];then
        mkdir -p ${LDAP_DATA}
        chown -R openldap:openldap ${LDAP_DATA}
    fi
    if [ ! -d ${LDAP_DATA}/${NEWDOM} ];then
        mkdir -p ${LDAP_DATA}/${NEWDOM}
        chown -R openldap:openldap ${LDAP_DATA}/${NEWDOM}
    fi
    if [ ! -d ${LDAP_DATA}/${NEWDOM} ];then
        mkdir -p ${LDAP_DATA/${NEWDOM}}
        chown -R openldap:openldap ${LDAP_DATA/${NEWDOM}}
    fi

    # Create our conf dir
    if [ ! -d ${LDAP_DOMAINS} ];then
        mkdir -p ${LDAP_DOMAINS}
        chown -R openldap:openldap ${LDAP_DOMAINS}
    fi

    if [ "${TYPE}" == "replica" ]; then
        PROVIDER=$(ldap_providers_for ${NEWBDN}|sed -e 's/ *//g')
        if [ -f "${LDAP_DOMAINS}/${NEWDOM}_replica.conf" ];then
            NEXT_RID=$(
                        grep "syncrepl *rid=" "${LDAP_DOMAINS}/${NEWDOM}_replica.conf" 2>/dev/null| \
                          sed -e 's/.*syncrepl *rid=//g' -e 's/#.*//'
                      )
            sed -e "s/<% NEXT_RID %>/${NEXT_RID}/g"      \
                -e "s/<% PROVIDER_URI %>/ldaps:\/\/${PROVIDER}:636/g"  \
                -e "s/<% BASE_DN %>/${NEWBDN}/g"         \
                -e "s/<% SELF_BASE_DN %>/${MYBASEDN}/g"  \
                -e "s/<% HOSTNAME_S %>/$(hostname -s)/g" \
                -e "s/<% SECRET %>/$(secret)/g"          \
               ${TEMPLATE_DIR}/domain_replica.conf.tpl   \
              > ${LDAP_DOMAINS}/${NEWDOM}_replica.conf.new
            if [ $(diff ${LDAP_DOMAINS}/${NEWDOM}_replica.conf ${LDAP_DOMAINS}/${NEWDOM}_replica.conf.new |wc -l) -gt 0 ];then
                mv ${LDAP_DOMAINS}/${NEWDOM}_replica.conf.new ${LDAP_DOMAINS}/${NEWDOM}_replica.conf
                SLAPD_NEEDS_RELOADED=1;
            else
                rm ${LDAP_DOMAINS}/${NEWDOM}_replica.conf.new
            fi
        else
            NEXT_RID=$(next_rid)
            sed -e "s/<% NEXT_RID %>/${NEXT_RID}/"      \
                -e "s/<% PROVIDER_URI %>/ldaps:\/\/${PROVIDER}:636/"  \
                -e "s/<% BASE_DN %>/${NEWBDN}/"       \
                -e "s/<% SELF_BASE_DN %>/${MYBASEDN}/g"  \
                -e "s/<% HOSTNAME_S %>/$(hostname -s)/" \
                -e "s/<% SECRET %>/$(secret)/"          \
               ${TEMPLATE_DIR}/domain_replica.conf.tpl  \
              > ${LDAP_DOMAINS}/${NEWDOM}_replica.conf
             SLAPD_NEEDS_RELOADED=1;
        fi
    fi
    chown openldap:openldap  ${LDAP_DOMAINS}/${NEWDOM}_replica.conf
    chmod 400 ${LDAP_DOMAINS}/${NEWDOM}_replica.conf
    if [ ! -f ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf ];then
        sed -e "s/<% DOMAIN %>/${NEWDOM}/"   \
            -e "s/<% BASE_DN %>/${NEWBDN}/" \
            -e "s/<% NOT_ME %>/${NOT_ME}/"   \
           ${TEMPLATE_DIR}/domain_slapd.conf.tpl \
          > ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf
        SLAPD_NEEDS_RELOADED=1;
    else 
        sed -e "s/<% DOMAIN %>/${NEWDOM}/"   \
            -e "s/<% BASE_DN %>/${NEWBDN}/" \
            -e "s/<% NOT_ME %>/${NOT_ME}/"   \
           ${TEMPLATE_DIR}/domain_slapd.conf.tpl \
          > ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf.new
        if [ $(diff ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf.new|wc -l) -gt 0 ];then
            mv ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf.new ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf
            SLAPD_NEEDS_RELOADED=1;
        else
            rm ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf.new 
        fi
    fi
    chown openldap:openldap  ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf
    chmod 400  ${LDAP_DOMAINS}/${NEWDOM}_slapd.conf
}

do_nothing(){
   echo -n
}

write_replication_config(){
    rootpw
    slapd_domains_conf ${domain}
    domain_slapd.conf ${domain} replica
}

write_provider_config(){
    rootpw
    slapd_domains_conf ${domain}
    domain_slapd.conf ${domain} provider
}
  

################################################################################
# main.c, yo.
################################################################################
if [ we_can_bind ];then
    for nc in $(naming_contexts);do 
        domain=$(echo ${nc}|sed -e 's/,dc=/./g' -e 's/^dc=//g')
        IS_PROVIDER=0; IS_REPLICA=0;
        for replica in `ldap_replicas_for ${nc}`;do
            if [ "${replica}" == "${MYHOST}.${MYDOMAIN}" ];then
                IS_REPLICA=1;
                NOT_ME=''
            fi
        done
        for provider in `ldap_providers_for ${nc}`; do
            if [ "$provider" == "${MYHOST}.${MYDOMAIN}" ];then
                IS_PROVIDER=1;
                NOT_ME='# NOT ME # '
            fi
        done
        if [ ${IS_REPLICA} -eq 1 -a ${IS_PROVIDER} -eq 1  ];then
            echo "I cannot be both a replica and a provider. Fix LDAP. Aborting..."
            exit 1;
        fi 
        ########################################################################
        # Now that we've determined our role, let's do some real work
        ########################################################################
        if [ ${IS_REPLICA} -eq 1 ];then
            echo "I am a replica of $(ldap_providers_for ${nc}) for ${domain}"
            write_replication_config $domain    
        else 
            if [ ${IS_PROVIDER} -eq 1 ];then
                echo "I am a provider for ${domain}"
                write_provider_config $domain    
            else
                do_nothing
            fi 
        fi
    done
    if [ "${SLAPD_NEEDS_RELOADED}" == "1" ];then
        /etc/init.d/slapd restart
    fi
else
    echo "we can't bind to any ldap server, trying to make determination based on DNS"
    COUNT=0
    for srv in $(dig +short -tsrv _ldap._tcp.websages.com | sort -rn |awk '{print $NF}'|sed -e 's/\.$//') ; do
        COUNT=$(expr ${COUNT} + 1)
        if [ ${COUNT} -eq  1 ];then PROVIDER=${srv}; fi
        if [ "${srv}" == "$(hostname -f)" ];then
            if [ ${COUNT} -eq  1 ];then 
                echo "I am a provider for $domain";
                write_provider_config $domain    
            else
                echo "I am a replica of rrovider ${PROVIDER} for $domain";
                write_replication_config $domain    
            fi
        fi
    done
    exit 0
fi
