$TTL 86400

thebikeshed.io. 3600 SOA ns1.thebikeshed.io. admin.thebikeshed.io. (
    0001    ; serial
    1800    ; refresh
    7200    ; retry
    1209600 ; expire
    3600 )  ; negative

    IN NS ns1.thebikeshed.io.

ns1             IN A 10.255.0.1
planck          IN A 10.255.2.244
octoprint       IN CNAME planck
puppycam        IN CNAME planck
