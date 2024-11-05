**[Amoeba](https://github.com/sh4run/amoeba)**

**A proxy derived from SSS(scrambled shadowsocks) with a brand new architecture and a enhanced protocol.**

----

**Feel free to open an issue if you see any when using/compiling sss.**

[Original Readme](https://github.com/sh4run/sss/tree/d3e73c6ce652168963cb10c8284c89f2cf4df16e#readme)

[A fast installation script](https://github.com/sh4run/scripts-configs#sssscrambled-shadowsocks-installation)

# SSS - Scrambled Shadowsocks
## Objective
Tests show, with the help of [IP Geolocation Based Filtering](https://github.com/sh4run/sss#ip-geolocation-based-filtering), when a new shadowsocks server comes online, GFW probes are received immediately after the first connection is initiated. This means GFW can identify shadowsocks precisely, not by any traffic measurement, or any mysterious big data analysis, but by some characteristics of shadowsocks itself.  More tests show very likely this characteristic is the length of the packets.

The purpose of this modified protocol is to fix this problem while reusing existing shadowsocks code as much as possible. Following issues are to be addressed here:
1. Variable or random packet length
2. Secrecy
3. Anti-replay
4. Multi-client/device service

## Protocol
SSS changes orginal SS stream format in both upstream and downsteam. Most changes are in upstream. 

Upstream changes:
1. Divides original SS upstream data into multiple pieces, each piece in a random length.
2. Mixes those pieces into multiple segments of random bytes. In another words, SS data is split into pieces and mixed into a stream of random bytes. This is the reason it is called scrambled shadowsocks.
3. Each TCP connection has its own mixing scheme.
4. An encrypted header is added to instruct its peer how to decode.
5. This encrypted header is padded with random bytes at both head and tail. An outside observer is difficult to locate the actual content.

Downstream Changes:
1. A piece of random bytes is prepended. 

With these changes, SSS is trying to make its frame have no obvious pattern (either length or content). So that it would be difficult to use any existing pattern match to detect SSS.


    Stream Format 

    client --> Server
    --------------------------------------------------------------------------
    | Pad-1 | session header(encrypted) | Pad-tail | TLV-1 | TLV-2 ...
    --------------------------------------------------------------------------                            

    Server --> Client
    --------------------------------------------------------------------------
    | Pad-2 | Shadowsocks data ...
    --------------------------------------------------------------------------

    Pad-1
    This is a piece of random data added at the beginning of each TCP
    connection. The length of this piece is defined as scramble-x.

    scramble-x
    A shared constant between a server and its clients. Different servers can
    choose different value.

    Session header
    Session header is encrypted by the RSA public key of the server. It includes:
    - Length of Pad-tail & Pad-2.
    - Type values used in TLV.
    - Epoch


    TLVs (Type-Length-Value)
    There are two types: data and pad. The type values are specified in
    session-header. These values are different in different connections. 
    A client can choose to send out TLVs in random order with random length
    of data or pad. 
    The data here refers to the original shadowsocks data.
    
A typical config in scrambled shadowsocks includes:
  - scramble-X 
  - client-id (only at client side, not used at this moment)
  - server public key or private key
  - shadowsocks config
                            
## Build

One extra package is needed: libsystemd-dev. SSS is based on openssl 3.0. You might need to update to ubuntu 22.04 to install libssl-dev 3.0.

To install the new package: 

    sudo apt install libsystemd-dev
    
If not installed yet, old packages can be installed by

    sudo apt-get install build-essential autoconf libtool libssl-dev 
    sudo apt-get install gawk debhelper  init-system-helpers pkg-config asciidoc xmlto 
    sudo apt-get install apg libpcre3-dev zlib1g-dev libev-dev libudns-dev 
    sudo apt-get install libsodium-dev libmbedtls-dev libc-ares-dev automake

Create a view and build. The results are under subdir "src".

    git clone https://github.com/sh4run/sss.git
    cd sss
    git submodule update --init
    ./autogen.sh
    ./configure
    make

If you want to use **IP Geolocation Based Filtering**, you still need to follow the instructions [here](https://github.com/sh4run/sss#ip-geolocation-based-filtering) .

## Usage

### Configuration

Generate your public/private key with:

    ssh-keygen -b 1024 -m pem -f my-key
    ssh-keygen -m pem -e -f my-key >my-key.pub.pem
    
Now your private key is "my-key" and public key is "my-key.pub.pem".

**New configs are only supported in JSON config file.**

An example config file at server side (server.json):

    {
        "server":["0.0.0.0"],
        "server_port":3456 or whatever,
        "password":"Your-Password",
        "timeout":40,
        "method":"aes-128-gcm or whatever",
        "external_validation":"/Path/validate_ip_geo.sh",
        "private_key":"/Path-to-PrivateKey/PrivateKey-file-in-PEM",
        "scramble_length":123(recommended range 20~300)
    }

An example config file at client side (local.json):

    {
        "server":["server-ip"],
        "server_port":3456 or wahtever,
        "password":"your-Password",
        "timeout":40,
        "method":"aes-128-gcm",
        "local_port":5678(local socks port),
        "local_address":"0.0.0.0",
        "scramble_length":same as the number at server side,
        "public_key":"/PATH/PublicKey-In-PEM"                                                               
    }

In sss. **aead is no longer so important.** You can choose any other faster encryption method as well. 

### Deployment

Two ubuntu boxes are required to deploy SSS: one public server outside firewall, and another private server inside firewall as a first level proxy. As ss-local doesn't provide any authentication/encryption at this moment, it is recommended to use a machine in your private(home) network as the second box. 
* Run sss-server at your public server(VPS): **sss-server -c server.json**
* Run sss-local at your local ubuntu box: **sss-local -c local.json** 
* Run any socks5 client (v2rayng/SagerNet/Clash/Shadowrocket all support socks5) at your end device to connect to your local ubuntu box.

## Test Results

The first SSS server was online for 10 days with total 90G+ traffic (bidirectional at server side). It was stopped intentionally.
* NO GFW probes were received in the first a couples of days. 
* As traffic went up, some GFW probes were received in burst. 5~10 are probes were received in a short interval. Then it became quite for another two or three days. 

The latest version of sss server has been online for 4 months+ with 2T+ bidirectional traffic. It is still working now.

# IP Geolocation Based Filtering

**Unfortunately, the fact is, even with this extension, the test instance is still blocked by GFW in its grand operation.**

**It appears that the key point is how to avoid recceiving probes/replays, instead of how to handle them properly.**

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

