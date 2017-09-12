#!/bin/sh


while true; 
do
  if [ "$(pidof vyprvpn)" ]; then
    sleep 5;
  else
    /tmp/var/vyprvpn/scripts/run_vypr.sh;
    exit;
  fi
done
