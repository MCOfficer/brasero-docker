#!/bin/sh
# Stolen from
# https://github.com/jlesage/docker-handbrake/blob/master/rootfs/etc/cont-init.d/95-check-optical-drive.sh
# https://github.com/jlesage/docker-baseimage/blob/master/rootfs/etc/cont-init.d/10-init-users.sh

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

log() {
    echo "[cont-init.d] $(basename $0): $*"
}

user_id_exists() {
    [ -f /etc/passwd ] && cat /etc/passwd | cut -d':' -f3 | grep -q "^$1\$"
}

user_name_exists() {
    [ -f /etc/passwd ] && cat /etc/passwd | cut -d':' -f1 | grep -q "^$1\$"
}

group_id_exists() {
    [ -f /etc/group ] && cat /etc/group | cut -d':' -f3 | grep -q "^$1\$"
}

group_name_exists() {
    [ -f /etc/group ] && cat /etc/group | cut -d':' -f1 |grep -q "^$1\$"
}

add_group() {
    DUPLICATE_CHECK=true
    if [ "$1" = "--allow-duplicate" ]; then
        DUPLICATE_CHECK=false
        shift
    fi

    NAME="$1"
    GID="$2"

    if $DUPLICATE_CHECK && group_id_exists "$GID"; then
        echo "ERROR: group ID '$GID' already exists."
        return 1
    elif $DUPLICATE_CHECK && group_name_exists "$NAME"; then
        echo "ERROR: group '$NAME' already exists."
        return 1
    fi

    echo "$NAME:x:$GID:" >> /etc/group
}

add_user_to_group() {
    UNAME="$1"
    GNAME="$2"

    if ! user_name_exists "$UNAME"; then
        echo "ERROR: user '$UNAME' doesn't exists."
        exit 1
    elif ! group_name_exists "$GNAME"; then
        echo "ERROR: group '$GNAME' doesn't exists."
        exit 1
    fi

    if cat /etc/group | grep -q "^$GNAME:.*:$"; then
        sed-patch "/^$GNAME:/ s/$/$UNAME/" /etc/group
    else
        sed-patch "/^$GNAME:/ s/$/,$UNAME/" /etc/group
    fi
}

log "looking for usable optical drives..."

DRIVES_INFO="$(mktemp)"
lsscsi -g -k | grep -w "cd/dvd" | tr -s ' ' > "$DRIVES_INFO"

while read -r DRV; do
    DRV_DEV="$(echo "$DRV" | rev | sed -e 's/^[ \t]*//' | cut -d' ' -f2 | rev)"

    if [ -e "$DRV_DEV" ]; then
        # Save the associated group.
        DRV_GRP="$(stat -c "%g" "$DRV_DEV")"
        log "found optical drive $DRV_DEV, group $DRV_GRP."
        
        if ! group_id_exists "$DRV_GRP"; then
            add_group "grp$DRV_GRP" "$DRV_GRP"
        fi
        add_user_to_group root "grp$DRV_GRP"
    else
        log "found optical drive $DRV_DEV, but it is not usable because is not exposed to the container."
    fi
done < "$DRIVES_INFO"
rm "$DRIVES_INFO"

# vim: set ft=sh :