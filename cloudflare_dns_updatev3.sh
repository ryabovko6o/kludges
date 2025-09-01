#!/bin/bash

# This script updates the Cloudflare's A DNS records for your domain.
# It requires the DNS edit token key and the DNS Zone ID.
# The script uses curl for the API calls and awk parse the responses.
# Be sure to create the subdomain A DNS record in the Cloudflare portal with a dummy routable IP address first.

SUBDOMAIN=<example.tld>
KEY=<Cloudflare Token Key for the DNS zone>
ZONE_ID=<Cloudflare DNS zone ID>

# Function to validate IP address
validate_ip() {
    local ip=$1

    # Regular expression to match valid IPv4 addresses
    local valid_ip_regex="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$"

    # Regular expressions to exclude non-routable IP addresses
    local non_routable_regexes=(
        "^0\.([0-9]{1,3}\.){2}[0-9]{1,3}$"
        "^10\.([0-9]{1,3}\.){2}[0-9]{1,3}$"
        "^100\.(6[4-9]|7[0-9]|1[0-1][0-9]|12[0-7])\.([0-9]{1,3}\.)[0-9]{1,3}$"
        "^127\.([0-9]{1,3}\.){2}[0-9]{1,3}$"
        "^169\.254\.([0-9]{1,3}\.)[0-9]{1,3}$"
        "^172\.(1[6-9]|2[0-9]|3[0-1])\.([0-9]{1,3}\.)[0-9]{1,3}$"
        "^192\.0\.0\.([0-9]{1,3})$"
        "^192\.0\.2\.([0-9]{1,3})$"
        "^192\.88\.99\.([0-9]{1,3})$"
        "^192\.168\.([0-9]{1,3}\.)[0-9]{1,3}$"
        "^198\.(1[8-9])\.([0-9]{1,3}\.)[0-9]{1,3}$"
        "^198\.51\.100\.([0-9]{1,3})$"
        "^203\.0\.113\.([0-9]{1,3})$"
        "^224\.([0-9]{1,3}\.){2}[0-9]{1,3}$"
        "^(24[0-9]|25[0-5])\.([0-9]{1,3}\.){2}[0-9]{1,3}$"
    )

    # Check if the IP address matches the valid IP regex
    if [[ $ip =~ $valid_ip_regex ]]; then
        # Check if the IP address matches any of the non-routable IP regexes
        for regex in "${non_routable_regexes[@]}"; do
            if [[ $ip =~ $regex ]]; then
                echo "Invalid IP address: Non-routable IP address"
                return 1
            fi
        done
        echo "$ip is a valid IP address"
        return 0
    else
        echo "Invalid IP address: Does not match IPv4 format"
        return 1
    fi
}

# Get old IP address
OLD_IP=$(host $SUBDOMAIN | awk '/has address/ { print $4 }')
if validate_ip "$OLD_IP"; then
  echo "Old IP for $SUBDOMAIN is $OLD_IP"
else
  echo "Failed getting old IP"
  exit 1
fi

# Get new IP address
NEW_IP=$(curl -s --connect-timeout 20 https://checkip.amazonaws.com)
if validate_ip "$NEW_IP"; then
  echo "New IP for $SUBDOMAIN is $NEW_IP"
else
  echo "Failed getting new IP"
  exit 1
fi

# Compare the IP addresses
if [ "$NEW_IP" == "$OLD_IP" ]; then
    echo "IP is already correct"
else

# Get Subdomain DNS Record from Cloudflare
DNS_RECORD_ID=$(curl -s --connect-timeout 20 --request GET \
    --url https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $KEY" \
        | awk -v RS='{"' -F: '/^id/ && /'"$SUBDOMAIN"'/{print $2}' | tr -d '"' | sed 's/,.*//')
echo "Got Record ID"

# Update IP Address
curl -s -o /dev/null --connect-timeout 20 --request PUT \
  --url https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer $KEY" \
  --data "{\"type\":\"A\",\"name\":\"$SUBDOMAIN\",\"content\":\"$NEW_IP\",\"ttl\":1,\"proxied\":false}" 
echo "IP address for $SUBDOMAIN is updated to $NEW_IP"

fi

exit 0
