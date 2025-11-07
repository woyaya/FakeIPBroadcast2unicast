#!/bin/bash
# Variables
REALPATH=`realpath $0 2>/dev/null`
[ -z "$REALPATH" ] && REALPATH="$0"
EXEC=`basename $REALPATH`
DIR=`dirname $REALPATH`
export REALPATH EXEC DIR

#1: ERR; 2:ERR+WRN; 3:ERR+WRN+INF
LOG_LEVEL=${LOG_LEVEL:-2}
LOG2LOGGER=${LOG2LOGGER:-0}
DEBUG=${DEBUG:-0}
BASE=$DIR
DRYRUN=""
#Functions
############################
USAGE(){
	echo "Conver broadcast to unicast for fake IP listed"
	echo "Usage: $1 [params] -l list_file"
	echo "     -l list_file: list file"
	echo "     -B dir: base dir, where to find functions. default: $BASE"
	echo "     -n: dry run, perform a trial run with no changes made"
	echo "     -v: more verbose output"
	echo "     -L: log to logger"
	echo "     -D: debug mode"
	echo "     -h: print this"

	exit -1
}


#_ebtable_subnet2mac subnet
_ebtable_subnet2mac(){
	local setting
	setting=`ebtables -t nat -L PREROUTING 2>/dev/null | grep "dnat" | grep $1`
	get_mac "$setting"
	return 0
}
#ebtable_set subnet mac
ebtable_set(){
	echo "ebtables -t nat -A PREROUTING -p IPv4 --ip-dst $1 -j dnat --to-destination $2"
	[ -n "$DRYRUN" ] && return
	ebtables -t nat -A PREROUTING -p IPv4 --ip-dst $1 -j dnat --to-destination $2
}
#ebtable_clear subnet
ebtable_clear(){
	local _mac
	_mac=`_ebtable_subnet2mac $1`
	[ -z "$_mac" ] && return 0
	INF "Clear ebtables setting: $subnet with mac: $_mac"
	echo "ebtables -t nat -D PREROUTING -p IPv4 --ip-dst $1 -j dnat --to-destination $_mac 2>/dev/null"
	[ -n "$DRYRUN" ] && return
	ebtables -t nat -D PREROUTING -p IPv4 --ip-dst $1 -j dnat --to-destination $_mac 2>/dev/null
	return 0
}

# ip2mac ip
ip2mac(){
	get_mac $(arp -n $1 2>/dev/null)
}

LIST=""
############################
while getopts ":B:r:b:H:l:P:p:RnvLD" opt; do
	case $opt in
		B)
			BASE=$OPTARG
		;;
		l)
			LIST=$OPTARG
		;;
		n)
			DRYRUN="-n"
		;;
		v)
			LOG_LEVEL=$((LOG_LEVEL+1))
		;;
		L)
			LOG2LOGGER=1
		;;
		D)
			DEBUG=1
			LOG_LEVEL=999
		;;
		*)
			USAGE $0
		;;
	esac
done

export DEBUG
export LOG_LEVEL
export BASE

COMMON=$BASE/common.sh
[ ! -f $COMMON ] && COMMON=$BASE/functions/common.sh
[ ! -f $COMMON ] && COMMON=$BASE/functions/shell/common.sh
[ ! -f $COMMON ] && {
	echo "Invalid setting! file \"$COMMON\" not exist"
	exit 1
}
export COMMON
. $COMMON

[ -z "$LIST" ] && USAGE $0
[ ! -f "$LIST" ] && ERR "Can not found list file: $LIST"

check_dirs $BASE || ERR "Incomplete dirs" 
#check_execs ebtables arp logger grep sed awk wc || ERR "Incomplete executes"

#trap cleanup EXIT

INF "Process list start: $LIST"
while read LINE; do
	DBG "Process line: $LINE"
	[ -z "$LINE" ] && continue
	line=`echo "$LINE" | sed 's/^ *//;/^#/d'`
	DBG "Ignore annotation: $line"
	[ -z "$line" ] && continue

	subnet=`echo "$line" | awk -F'->' '{print $1}'`
	ip=`echo "$line" | awk -F'->' '{print $2}'`
	check=`echo "$line" | awk -F'->' '{print $3}'`
	DBG "Subnet: $subnet, IP: $ip, check: $check"
	[ -n "$check" ] && {
		line_fail "$line" "Invalid line(Too many params)"
		continue
	}
	check_variables ip || {
		line_fail "$line" "Invalid line(Too less params)"
		continue
	}
	mac=`ip2mac $ip`
	DBG "MAC: $mac"
	[ -z "$mac" ] && {
		INF "No arp entry for IP:$ip"
		ebtable_clear $subnet
		continue
	}
	# Check if already set
	mac_set=$(_ebtable_subnet2mac $subnet)
	[ "$mac_set" = "$mac" ] && continue
	[ -n "$mac_set" ] && {
		WRN "The MAC of the subnet($subnet) has changed: $mac_set->$mac, clear it"
		ebtable_clear $subnet
	}
	INF "Set subnet($subnet) target as $ip($mac)"
	ebtable_set $subnet $mac
	ret=$?
	[ "$ret" != "0" ] && {
		ERR "Ebtable set fail: subnet:$subnet, IP:$ip($mac)"
		continue
	}
	INF "Ebtable set success: $subnet->$ip($mac)"
done <$LIST
INF "Process list end: $LIST"

INF "Actiion done: $LIST"
