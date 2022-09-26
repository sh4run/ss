##!/bin/bash
#
# This script uses API from https://app.ipgeolocation.io to
# find the geographical location of an IP address. 
# It compares the returned city with the pre-defined
# $MYCITY  and returns 0/1.   
#
# Usage:
#    validate_ip_geo.sh <ip-addr>
# Return Value:
#    0   if city matches.
#    1   no match.
#

#
# To use its service, please subscribe to ipgeolocation.io. 
# The developer plan provides 1000 free API calls per day.  
# Please fill in your ipgeolocation.io API key below. 
#
MYKEY=__YOU__KEY__FROM__ipgeolocation__

#
# Please fill in the city name.
#
MYCITY=Beijing

IPADDR=$1

result=`curl "https://api.ipgeolocation.io/ipgeo?apiKey=$MYKEY&ip=$IPADDR&fields=city" 2>/dev/null`

cc=`echo $result | python3 -c "import sys, json; print(json.load(sys.stdin)['city'])"`

rtn=1
if [ "$cc" = "$MYCITY" ]; then
    rtn=0
fi

exit $rtn
