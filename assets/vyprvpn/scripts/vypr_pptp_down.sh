#!/bin/sh

dns_resolv_file="/tmp/ppp/resolv.conf"
pptp_saved_args="/tmp/var/vyprvpn/scripts/pptp_saved_args"
firewall_dir="/etc/openvpn/fw"
firewall_file="/etc/openvpn/fw/vypr_pptp_rules"
lan_ipaddr=$(/bin/nvram get lan_ipaddr)
lan_netmask=$(/bin/nvram get lan_netmask)

delete_routes_from_main()
{
  /usr/sbin/ip route del 128.0.0.0/1 via $5 dev $1
  /usr/sbin/ip route del 0.0.0.0/1 via $5 dev $1
  /usr/sbin/ip route del $5 dev $1
}

delete_firewall_rules()
{
  /usr/sbin/iptables -D OUTPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1
  /usr/sbin/iptables -D INPUT --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1
  /usr/sbin/iptables -D FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --out-interface $1
  /usr/sbin/iptables -D FORWARD --source 0.0.0.0/0.0.0.0 --destination 0.0.0.0/0.0.0.0 --jump ACCEPT --in-interface $1
  /usr/sbin/iptables -D FORWARD --protocol tcp --tcp-flags SYN,RST SYN --jump TCPMSS --clamp-mss-to-pmtu
  /usr/sbin/iptables -t nat -D POSTROUTING -s $lan_ipaddr/$lan_netmask -o $1 -j MASQUERADE
  if [ "$(/bin/nvram get pptp_client_nat)" = "1" ]; then
      /usr/sbin/iptables --table nat -D POSTROUTING --out-interface $1 --jump MASQUERADE
  fi
}

clean_up()
{
  /bin/rm $firewall_file
  /bin/rm $pptp_saved_args
}

restart_dns()
{
  /bin/rm $dns_resolv_file
  /sbin/service dnsmasq restart  
}

# args won't be set if we're calling this
# script directly from the vypr daemon
if [ -z ${1+x} ]; then
  set -- $(cat $pptp_saved_args)
fi

case "$6" in
kelokepptpd)

  delete_routes_from_main "$@"
  delete_firewall_rules "$@"
  clean_up
  restart_dns

  ;;
*)
esac   
