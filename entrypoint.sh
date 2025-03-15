#! /bin/sh

# List of PIDS of the port forward porcesses
TUNNEL_PIDS=""
UPDATE_DNS=0
TARGET_IP=""

log()
{
    echo "$(date) - $1"
}

# Function to check for IPv6
is_ipv6()
{
    ip -6 route get "$IP6_TARGET_HOST"/128 >/dev/null 2>&1  
    case "$?" in
        0|2) return 0 ;;
        *) return 1 ;;
    esac
}

is_dns()
{
    echo "$IP6_TARGET_HOST" | perl -ne "print if '/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$|^[\w\d_-]+$/'"
}

check_preconditions()
{
    if [ -z "$IP6_TARGET_HOST" ]; then
        log "ERROR: IP6_TARGET_HOST not set! Please define IP6_TARGET_HOST as the target host to forward the IPv4 traffic!"
        exit 1
    fi

    if is_ipv6; then
        log "$IP6_TARGET_HOST is a valid IPv6 address."
        TARGET_IP=$IP6_TARGET_HOST
    elif is_dns; then
        log "$IP6_TARGET_HOST is a valid DNS name."
        UPDATE_DNS=1
        resolve_target_ip
    else
        log "ERROR: $IP6_TARGET_HOST is neither a valid IPv6 address not a valid hostname or domain name!"
        exit 1
    fi

    if [ -z "$FORWARD_PORTS" ]; then
        log "ERROR: FORWARD_PORTS not set! Please define a comma seperated list of ports to forward IPv4 traffic from to the same IPv6 ports on $IP6_TARGET_HOST!"
        exit 1
    fi

    log "Forward ports: $FORWARD_PORTS"
}

resolve_target_ip()
{
    log "Resolving IPv6 address of '$IP6_TARGET_HOST'..."
    NEW_TARGET_IP=$(nslookup -type=aaaa "$IP6_TARGET_HOST" | awk '/^Address: / { print $2; exit }')

    if [ -z "$NEW_TARGET_IP" ]; then
        log "Failed to resolve IPv6 address!"
        stop_port_forwards
        exit 1
    elif [ "$NEW_TARGET_IP" != "$TARGET_IP" ]; then
        log "IP address has changed from '$TARGET_IP' to '$NEW_TARGET_IP'!"
        TARGET_IP=$NEW_TARGET_IP
        return 1
    else
        log "IP address hasn't changed, nothing to do!"
        return 0
    fi
}

start_port_forwards()
{
    log "Setting up IPv4-to-IPv6 traffic for '[$TARGET_IP]'..."
    for ports in $(echo "$FORWARD_PORTS"); do
        source_port=$(echo "$ports" | cut -d ',' -f1)
        target_port=$(echo "$ports" | cut -d ',' -f2)
        log "Forwarding port ${source_port}@IP4 to ${target_port}@IP6..."
        6tunnel $source_port $TARGET_IP $target_port &
        TUNNEL_PID=$(ps -ef | grep "6tunnel $source_port $TARGET_IP $target_port" | grep -v grep | awk '{print $1}')
        if [ -z "$TUNNEL_PID" ]; then
            log "Failed to start 6tunnel process for port $source_port!"
            stop_port_forwards
            exit 1
        fi
        log "Started tunnel process with PID=$TUNNEL_PID!"
        TUNNEL_PIDS="$TUNNEL_PIDS $TUNNEL_PID"
    done
}

stop_port_forwards()
{
    log "Stopping 6tunnel processes..."
    for PID in $TUNNEL_PIDS; do
        log "Stopping 6tunnel process with PID=$PID..."
        kill -9 "$PID"
    done
    log "All 6tunnel processes stopped!"
}

check_preconditions

start_port_forwards

# Infinite loop with sleep
log "Setup complete, going to sleep to let tunneling work..."
while true; do
    sleep 3600  # Sleep for 1h, then repeat
    log "HEARTBEAT!"
    
    if [ "$UPDATE_DNS" = "1" ]; then
        resolve_target_ip
        if [ "$?" = "1" ]; then
            log "Restarting ip4-to-ip6 forwarding..."
            stop_port_forwards
            start_port_forwards
        fi
    fi
done

stop_port_forwards
