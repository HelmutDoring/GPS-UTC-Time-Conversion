#!/bin/ksh

URL='https://astroutils.astronomy.osu.edu:443/time/tai-utc.txt'

URL_rx='(?:([^\:]*)\:\/\/)?(?:([^\:\@]*)(?:\:([^\@]*))?\@)?(?:([^\/\:]*))?(?:\:([0-9]*))?\/(\/[^\?#]*(?=.*?\/)\/)?([^\?#]*)?(?:\?([^#]*))?(?:#(.*))?'

if [[ $URL =~ $URL_rx ]]
then
    print "${.sh.match[1]} | ${.sh.match[2]} | ${.sh.match[3]} | ${.sh.match[4]} | ${.sh.match[5]} | ${.sh.match[6]} | ${.sh.match[7]}"
fi
#exit

#exec 5<> /dev/tcp/myhost.com/80
## Flush input
#cat <&5 &
#printf "GET /getuser/Default.aspx?username=b772643 HTTP/1.0\r\n\r\n" >&5

HOST='astroutils.astronomy.osu.edu'
URI='/time/tai-utc.txt'
PORT='443'
OUTFILE='tai-utc.txt'

exec 4> "$OUTFILE"

echo -ne "GET $URI HTTP/1.1\r\nHost: $HOST\r\n\r\n" \
  | openssl s_client -tls1_2 -quiet -no_ign_eof -connect "$HOST:$PORT" >&4 2>&1


