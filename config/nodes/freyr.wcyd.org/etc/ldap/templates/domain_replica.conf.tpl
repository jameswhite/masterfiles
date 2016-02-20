syncrepl rid=<% NEXT_RID %>
        provider=<% PROVIDER_URI %>
        bindmethod=simple
        binddn="cn=<% HOSTNAME_S %>,ou=Hosts,<% SELF_BASE_DN %>"
        credentials=<% SECRET %>
        searchbase="<% BASE_DN %>"
        schemachecking=off
        type=refreshOnly
        interval=00:00:01:00
        retry="60 +"
updateref <% PROVIDER_URI %>
