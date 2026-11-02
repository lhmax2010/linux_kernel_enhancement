#!/bin/sh
# Installed by task6; do not run during installation (eth0 will disconnect).
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

log()
{
    logger -t lko-net-setup -- "$*"
}

run()
{
    "$@"
    rc=$?
    log "$* : exit=$rc"
    return "$rc"
}

run ip link set eth0 down || exit 1
if ! run ip link set eth0 address 2C:CF:67:A0:72:B5; then
    # Restore link availability even if the MAC change was rejected.
    run ip link set eth0 up
    exit 1
fi
run ip link set eth0 up || exit 1

service=ethernet_2ccf67a072b5_cable
read -r started ignored < /proc/uptime
started=${started%%.*}
deadline=$((started + 60))
log "waiting up to 60 seconds for $service"
while :; do
    read -r now ignored < /proc/uptime
    now=${now%%.*}
    if [ "$now" -ge "$deadline" ]; then
        log "service wait failed after 60 seconds: $service"
        exit 1
    fi
    # A bounded read-only ConnMan query also bounds a stalled D-Bus reply.
    services=$(dbus-send --system --print-reply --reply-timeout=1000 \
        --dest=net.connman / net.connman.Manager.GetServices 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ] && printf '%s\n' "$services" | grep -F -q "object path \"/net/connman/service/$service\""; then
        log "service found: $service"
        break
    fi
    read -r now ignored < /proc/uptime
    now=${now%%.*}
    if [ "$now" -ge "$deadline" ]; then
        log "service wait failed after 60 seconds: $service; last D-Bus exit=$rc"
        exit 1
    fi
    sleep 1
done
run connmanctl config "$service" --ipv4 manual 192.168.108.26 255.255.255.0 192.168.108.1 --nameservers 221.131.143.69 || exit 1

# DNS is best effort. Resolve the link before checking its actual filesystem.
if [ -L /etc/resolv.conf ]; then
    log '/etc/resolv.conf is a symbolic link'
else
    log '/etc/resolv.conf is not a symbolic link'
fi
dns_path=$(readlink -f /etc/resolv.conf)
if [ -z "$dns_path" ] || [ ! -f "$dns_path" ]; then
    log 'DNS skipped: resolved path is not an existing regular file'
    exit 0
fi
mount_options=$(findmnt -n -o OPTIONS -T "$dns_path")
rc=$?
log "DNS target=$dns_path; findmnt exit=$rc; options=$mount_options"
if [ "$rc" -ne 0 ]; then
    log 'DNS skipped: cannot determine mount options'
    exit 0
fi
case ,$mount_options, in
    *,rw,*) ;;
    *) log 'DNS skipped: target filesystem is not writable'; exit 0 ;;
esac
if [ ! -w "$dns_path" ]; then
    log 'DNS skipped: target file is not writable'
    exit 0
fi
if (printf '%s\n' 'nameserver 221.131.143.69' > "$dns_path"); then
    log 'DNS written successfully'
else
    log 'DNS write failed; continuing without failing the service'
fi
log 'network setup complete'
exit 0
