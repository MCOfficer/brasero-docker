#!/bin/ash

exit=0;
while [ $exit -eq 0 ];
do
    #xfburn
    dbus-launch brasero --brasero-media-debug
    exit=$?
done