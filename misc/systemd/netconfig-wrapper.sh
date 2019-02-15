#!/bin/bash

# This wrapper should run on bootup, after network services
# are started. If either IPv4 or IPv6 static addresses are
# missing from our running config,, then call tc-netconfig
# to attempt to generate a new config. Else, NOOP.

# safety first
set -euo pipefail
IFS=$'\n\t'

# vars
TEMPCFG=/tmp/ifcfg.new
CMD="/opt/tc-netconfig/bin/netconfig -s -o ${TEMPCFG}"
PROG=$(basename $0)

# check for static IP addresses
V4STATIC=$(/sbin/ip -4 addr show scope global permanent)
V6STATIC=$(/sbin/ip -6 addr show scope global permanent)

function check_autoconf {
  # check to see if we have a v6 dynamic address present
  /sbin/ip -6 addr show bond0 scope global dynamic
}

# if either static is missing, try to config
if [[ -z ${V4STATIC} ]] || [[ -z ${V6STATIC} ]]; then

  # first allow some time for autoconf to happen
	ACCHECK=$(check_autoconf)
	CONTROL=1
	while [[ -z ${ACCHECK} ]] && [[ ${CONTROL} -lt 9 ]]; do
    ACCHECK=$(check_autoconf)
		echo "Waiting up to 40 sec for IPv6 autoconf to complete"
		sleep 5
		ACCHECK=$(/sbin/ip -6 addr show bond0 scope global dynamic)
		((CONTROL++))
	done

  IPMI=$(command -v ipmitool || true)
  if [[ -n ${IPMI} ]]; then
    # if ipmitool installed, use BMC LAN IP as backup identifier
	  eval ${CMD} -i
  else
	  eval ${CMD}
  fi
	if [[ -f ${TEMPCFG} ]]; then
		DEV=$(grep -e '^DEVICE' ${TEMPCFG} | awk -F'=' '{print $2}')
		CFG="ifcfg-${DEV}"
		echo "${PROG}: Installing new ${CFG}"
		cp ${TEMPCFG} /etc/sysconfig/network-scripts/${CFG}
		systemctl restart network
    # force an ansible-pull full run after reconfig
    [[ -d /opt/ansible ]] && touch /opt/ansible/.KICKSTART_INIT
	fi
else
  # NOOP if we're already fully configured
  echo "Using existing network config"
fi

exit 0

