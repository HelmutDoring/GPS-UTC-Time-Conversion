#!/bin/ksh
#
# GPS/UNIX timestamp conversion.
#
# This *should* be an accurate reference
# implementation for conversion between
# the UNIX epoch and GPS epoch with proper
# consideration for leapseconds, WITHOUT
# requiring hand maintenance of a leapseconds
# file.
#
# Makes use of the canonical leapseconds file:
#
#    https://astroutils.astronomy.osu.edu/time/tai-utc.txt
#
# Requires the curl command: https://curl.haxx.se
# though it can be hand primed with a copy of the
# tai-utc.dat file if curl is not available.
#
# Phil Ehrens <phil@slug.org>
#

export LC_ALL=C # Generic optimization for non-unicode scripts

#
# Validate argument list
#
if [[ ! "$1" =~ (gps2unix|unix2gps) ]] || \
   [[ ! "$2" =~ ^\d+$ ]]
then
    print -- "Required args: (gps2unix|unix2gps) \$TIMESPEC" >&2
    exit
fi

if [ ! -d ${TMPDIR:=$HOME/.gpstime} ]
then
    mkdir -p "$TMPDIR"
fi

cache="$TMPDIR/tai-utc.dat"
# expected size of file (-1 byte vs string)
typeset -i min_cache_size=3320

time_url='https://astroutils.astronomy.osu.edu/time/tai-utc.txt'
http_cmd='/usr/bin/curl -k -s'
utc_cmd='/bin/date +%s --utc -d'
stat_cmd='/usr/bin/stat --format "%s %Y"'

#
# Unix time began at 1970-01-01T00:00:00Z = 0
# GPS  time began at 1980-01-06T00:00:00Z = 0
#
# date -d 1970-01-01T00:00:00Z +%s -> 0
# date -d 1980-01-06T00:00:00Z +%s -> 315964800
#
# According to tycho.usno.navy.mil:
#
# After December 2016,
#        TAI is ahead of UTC   by 37 seconds. (changes when leapsecs are added)
#        TAI is ahead of GPS   by 19 seconds. (does NOT change when leapsecs are added)
#        GPS is ahead of UTC   by 18 seconds. (changes when leapsecs are added)
#
typeset -i epochdiff=$((315964800+19))

typeset -i one_month=2592000

typeset -i time=0

gps2unix() {
  typeset -i i=0
  for i in $leapseconds
  do
      if [[ $(($time+$epochdiff-$i)) -lt ${leapdata[$i]} ]]
      then
         break
      fi
   done
   print -- $(($time+$epochdiff-$i))
}

unix2gps() {
   typeset -i i=0
   for i in $leapseconds
   do
      if [[ $time -lt ${leapdata[$i]} ]]
      then
         break
      fi   
   done
   print -- $(($time-$epochdiff+$i))
}

#
# Test the leapsecond cache file for
# existence and freshness
#
validatecache() {
   typeset -i mtime=0 age=0 size=0
   typeset -i now=$(/bin/date +%s)

   if [[ -f "$cache" ]] && [[ -r "$cache" ]]
   then
      set -A f -- $(eval $stat_cmd "$cache")
      mtime=${f[1]}
      size=${f[0]}
      age=$(($now - $mtime))
   fi

   if [[ ! -f "$cache" ]] || [[ "$age" -gt $((2*$one_month)) ]]
   then
      eval $http_cmd $time_url >"$cache"
      # Make absolutely certain the file gets flushed
      typeset fflush=$(<$cache)
   fi

   if [[ ! -r "$cache" ]]
   then
      print -- "Cache file: '$cache' not readable." >&2
      exit
   fi
}

#
# read the leapsecond cache file and
# initialize the leapsecond array
#
validatecache

IFS=$'\n'
data=$(<$cache)

if [[ ${#data} -lt $min_cache_size ]]
then
   print -- "\nCache file: '$cache' truncated:\n\n#~~~ begin ~~~" >&2
   print -- "$data" >&2
   print -- "#~~~ end ~~~\n" >&2
   print -- "You PROBABLY want to delete your cache file!\n" >&2
   exit
fi

#
# Lines in the leapseconds file 'tai-utc.dat' looks like this:
#
# 1968 FEB  1 =JD 2439887.5  TAI-UTC=  4.2131700 S + (MJD - 39126.) X 0.002592 S
# 1972 JAN  1 =JD 2441317.5  TAI-UTC=  10.0  S + (MJD - 41317.) X 0.0  S
# 1980 JAN  1 =JD 2444239.5  TAI-UTC=  19.0  S + (MJD - 41317.) X 0.0  S
# 2017 JAN  1 =JD 2457754.5  TAI-UTC=  37.0  S + (MJD - 41317.) X 0.0  S
# ^^^^ ^^^  ^                          ^^^^
# year mon day                      leapseconds
#
# Note that there were no leapseconds before 1972. This is the source of
# some errors in time conversion due to the UNIX epoch beginning in 1970.
#

typeset -A leapdata
typeset -i key=0 oldkey=0
for line in $data
do
   IFS=' '
   set -A a -- $line
   leapdate="${a[1]} ${a[2]} ${a[0]}"
   key="${a[6]}"
   if [[ "$key" -eq 0 ]]
   then
      print -- "Cache file: '$cache' corrupted." >&2
      exit
   fi
   if [[ "$key" -ne "$oldkey" ]]
   then
      leapdata[$key]=$($utc_cmd "$leapdate" 2>/dev/null)
      leapseconds+=" $key"
   fi
   oldkey="$key"
done

#
# Convert
#
time=$2
$1 $time
