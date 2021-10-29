#!/bin/bash
#
# Dynamic DNS
#
# Specific for Dreamhost
# Setup your API key here: https://panel.dreamhost.com/?tree=home.api
# Must have all DNS privs

# Config
dh_api_key=YOUR_KEY
domain="dyndns.example.com"
do_ipv4=true
do_ipv6=true
ip_echo_service="http://bot.whatismyipaddress.com/"

## No config below here

normalize_ipv6() {
    python -c "import socket; print(socket.inet_ntop(socket.AF_INET6, socket.inet_pton(socket.AF_INET6, '${1}')))"
}

get_ip() {
    curl -"$1" -s "$ip_echo_service"
}

add_dns() {
    curl -s "$dh_url&cmd=dns-add_record&record=$domain&type=$1&value=$2"
}

update_dns() {
    curl -s "$dh_url&cmd=dns-remove_record&record=$domain&type=$1&value=$2"
    add_dns $1 $3
}

process_new_ip() {
    if [ "$old_ip" == "" ]; then
        echo "No $type record found, creating one pointing to $new_ip..."
        add_dns $type $new_ip
        old_ip=$new_ip
    else
        if [ "$type" == "A" ]; then
            old_ip_comp="$old_ip"
            new_ip_comp="$new_ip"
        else
            old_ip_comp=$(normalize_ipv6 "$old_ip")
            new_ip_comp=$(normalize_ipv6 "$new_ip")
        fi

        echo "new ip: $new_ip ($new_ip_comp)"
        echo "old ip: $old_ip ($old_ip_comp)"
        if [ "$new_ip_comp" == "$old_ip_comp" ]; then
            echo "no change"
        else
            echo "different, updating..."
            update_dns $type $old_ip $new_ip
        fi
    fi
}

dyn_dns() {
    if [ "$1" == "4" ]; then type="A"; else type="AAAA"; fi
    echo "$(date) Checking $type record for $domain"
    old_ip=$(echo "$dns_records" | grep $domain | grep "\s$type\s"| cut -f 5)
    new_ip=$(get_ip "$1")

    if [ "$new_ip" == "" ]; then
        echo "Problem getting new ipv$1 ip, leaving things as they are..."
    else
        process_new_ip
    fi

}

dh_url="https://api.dreamhost.com/?key=$dh_api_key"
dns_records=$(curl -s "$dh_url&cmd=dns-list_records")

if [ "$do_ipv4" = true ]; then
    dyn_dns 4
fi

if [ "$do_ipv6" = true ]; then
    dyn_dns 6
fi
