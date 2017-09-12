#!/bin/sh

dns_dir="/tmp/ppp"
dns_resolv_file="/tmp/ppp/resolv.conf"
pptp_saved_args="/tmp/var/vyprvpn/scripts/pptp_saved_args"
firewall_dir="/etc/openvpn/fw"
firewall_file="/etc/openvpn/fw/vypr_pptp_rules"
status_file="/tmp/var/vyprvpn/pptp_status"
lan_ipaddr=$(/bin/nvram get lan_ipaddr)
lan_netmask=$(/bin/nvram get lan_netmask)

save_args()
{
  /bin/rm $pptp_saved_args
  for args
  do if [ -z $args ]; then echo -n "\"\" " >> $pptp_saved_args; else echo -n "$args " >> $pptp_saved_args; fi
  done
}

update_main_route_table()
{
  /usr/sbin/ip route del $5 dev $1                 # clear previous setting
  /usr/sbin/ip route add $5 dev $1
  /usr/sbin/ip route add 128.0.0.0/1 via $5 dev $1 # we're adding a default address, but in two parts because we
  /usr/sbin/ip route add 0.0.0.0/1 via $5 dev $1   # want it to override the default address that's there already
}

add_firewall_rules()
{
  /usr/sbin/iptables --insert OUTPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1
  /usr/sbin/iptables --insert INPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1
  /usr/sbin/iptables --insert FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1
  /usr/sbin/iptables --insert FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1
  /usr/sbin/iptables --insert FORWARD --protocol tcp --tcp-flags SYN,RST SYN --jump TCPMSS --clamp-mss-to-pmtu
  /usr/sbin/iptables -t nat -I POSTROUTING -s $lan_ipaddr/$lan_netmask -o $1 -j MASQUERADE
  if [ "$(/bin/nvram get pptp_client_nat)" = "1" ]; then
      /usr/sbin/iptables --table nat --append POSTROUTING --out-interface $1 --jump MASQUERADE
  fi
}

save_firewall_rules()
{
  if [ ! -d $firewall_dir ]; then mkdir -p $firewall_dir; fi
  echo "/usr/sbin/iptables --insert OUTPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1" > $firewall_file
  echo "/usr/sbin/iptables --insert INPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1" >> $firewall_file
  echo "/usr/sbin/iptables --insert FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1" >> $firewall_file
  echo "/usr/sbin/iptables --insert FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1" >> $firewall_file
  echo "/usr/sbin/iptables --insert FORWARD --protocol tcp --tcp-flags SYN,RST SYN --jump TCPMSS --clamp-mss-to-pmtu" >> $firewall_file
  echo "/usr/sbin/iptables -t nat -I POSTROUTING -s $lan_ipaddr/$lan_netmask -o $1 -j MASQUERADE" >> $firewall_file
  if [ "$(/bin/nvram get pptp_client_nat)" = "1" ]; then
      echo "/usr/sbin/iptables --table nat --append POSTROUTING --out-interface $1 --jump MASQUERADE" >> $firewall_file
  fi
  /bin/chmod 755 $firewall_file
}

add_dns()
{
  /bin/rm -rf $dns_dir
  /bin/mkdir -p $dns_dir

  for server in $(set | grep "DNS[1-2]")
  do
    echo $server |  sed "s/^DNS.='\(.*\)'/nameserver \1/" >> $dns_resolv_file
  done

}

save_args "$@"

case "$6" in
kelokepptpd)

  update_main_route_table "$@"
  add_firewall_rules "$@"
  save_firewall_rules "$@"
  add_dns
  sbin/service dnsmasq restart

  ;;
*)
esac

echo 2 > "$status_file" # communicate to vypr daemon that we are connected

exit 0
