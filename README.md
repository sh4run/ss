[Original Readme](https://github.com/sh4run/ss/tree/d3e73c6ce652168963cb10c8284c89f2cf4df16e#readme)


# IP Geolocation Based Filtering

## Intro

Probes and replays from GFW are threats a shadowsocks instance has to face every day. This feature introduces a new mechanism to filter out those malicious packets. Tests show GFW uses IP addresses all around China as source in those probes and replays. This is an effective method to undermine any blacklist at shadowsocks side. But this also gives a good chance to screen most of them based on IP geolocation if geolocation of the actual client is known for certain. 

The feature adds an external validation routine(EVR). In this routine, in shell script, an online DB is checked for the geolocation of the specified IP address.  The geolocation(city) is then compared with the known value and 0/1 is returned.  The online DB used here provides a free plan including 1000/day API calls. 

In shadowsocks, when an ingress connection is received, the EVR is invoked. The peer address is then added into a whitelist or blacklist based on the result. EVR isn't invoked again in any following connection from the same peer.  All connections are accepted. But if the peer is in a blacklist, packets from that connection are silently dropped. 

## Caveats

This feature is only applicable for personal or small scale deployment where the geolocation of the client IP is certain.  

This feature is not applicable in large business use cases where the shadowsocks service is provided to unspecified individuals. 

This feature can effectively screen probes and replays(95+%). But how much this can help any shadowsocks instance not to be blocked by GFW is unknown. 

Future GFW upgrades may obsolete this feature. 

## Installation

Please install shadowsocks-libev first. Make sure it works properly. 

### Build

Ubuntu 22.04, similar to [original instructions](https://shadowsocks.org/guide/deploying.html#github-3), no dh-systemd.

    sudo apt-get install --no-install-recommends build-essential autoconf libtool libssl-dev gawk debhelper  init-system-helpers pkg-config asciidoc xmlto apg libpcre3-dev zlib1g-dev libev-dev libudns-dev libsodium-dev libmbedtls-dev libc-ares-dev automake

    git clone https://github.com/sh4run/ss.git

    cd ss

    git submodule update --init

    ./autogen.sh && ./configure && make

### Config Changes 

Subscribe to [ipgeolocation.io](https://ipgeolocation.io). You can find your IP geography info in the same page. 

Change debian/validate_ip_geo.sh. Fill in your own key and your city.  Please verify the script by:

    debian/validate_ip_geo.sh  <your_ip>

    echo $?
    
0 is the expected result here.

Add one line to /etc/shadowsocks-libev/config.json:

    "external_validation":"/your-path/validate_ip_geo.sh"

Stop shadowsocks-libev:

    sudo systemctl stop shadowsocks-libev

Replace ss-server:

    sudo cp src/ss-server /usr/bin/ss-server

Start shadowsocks-libev:

    sudo systemctl start shadowsocks-libev

Check status:

    sudo systemctl status shadowsocks-libev

There should be a log like:

    2022-09-25 09:53:07 INFO: External validation(/xxx/validate_ip_geo.sh) installed.

Please check the path/access of the script if an error is displayed. 

