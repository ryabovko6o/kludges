#!/bin/sh

# Adopted from here
# https://github.com/Gobidev/wireguard-keepalive

# Function to validate IP address
validate_ip() {
  echo "$1" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null &&
  echo "$1" | awk -F'.' '{ if ($1<=255 && $2<=255 && $3<=255 && $4<=255) exit 0; else exit 1 }'
}

REMOTE=<FQDN of the remote peer>
FILE="/usr/local/trackip"

set -e

if [ -f "$FILE" ]; then
    :
else
    touch $FILE
    echo "10.10.10.10" > $FILE
fi

OLD_IP=$(cat $FILE)
NEW_IP=$(host $REMOTE | awk '/has address/ { print $4 }')
if validate_ip "$NEW_IP"; then
  echo "Got new IP: $NEW_IP"
else
  echo "Error getting remote IP. Exiting."
  exit 1
fi


if [ "$NEW_IP" = "$OLD_IP" ]; then
	echo "The IPs match. "$NEW_IP" = "$OLD_IP". No action needed."
else
  echo "Restarting Wireguard..."
  /usr/local/etc/rc.d/wireguardd restart && echo "$NEW_IP" > $FILE
  echo "Wireguard restarted."
fi

exit 0


