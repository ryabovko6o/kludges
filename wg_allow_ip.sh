#!/bin/vbash

# This script updates a firewall rule to allow connection from an IP address associated with a FQDN on an Ubiqiti Edge Router.
# This is benficial when you want to allow a single dynamic IP to be allowed through the firewall.
# Create a cron job to run this script every X minutes.

runcfg="/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper"
DOMAIN=<example.tld>
FIREWALL_GP=<wg_allow_ip>

$runcfg begin
OLD_IP=$($runcfg show firewall group address-group $FIREWALL_GP | awk '/address/ { print $NF }')
$runcfg end

NEW_IP=$(host $DOMAIN | awk '/has address/ { print $4 }')
if [[ "$NEW_IP" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
  :
else
  exit 1
fi

if [ "$NEW_IP" = "$OLD_IP" ]; then
	:
else
	$runcfg begin
	$runcfg delete firewall group address-group $FIREWALL_GP address > /dev/null 2>&1
	$runcfg set firewall group address-group $FIREWALL_GP address $NEW_IP
	$runcfg commit
	$runcfg end
fi

exit 0

