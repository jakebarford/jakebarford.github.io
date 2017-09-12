#!/bin/sh

dns_dir="/etc/openvpn/dns"
# filebase=`echo $filedir/$dev | sed 's/\(tun\|tap\)9/client9/;s/\(tun\|tap\)2/server/'`
dns_resolv_file="/etc/openvpn/dns/client9.resolv"
dns_conf_file="/etc/openvpn/dns/client9.conf"
firewall_dir="/etc/openvpn/fw"
firewall_file="/etc/openvpn/fw/vypr_rules"
openvpn_saved_variables="/var/vyprvpn/scripts/openvpn_saved_variables"
lan_ipaddr=`/bin/nvram get lan_ipaddr`
lan_netmask=`/bin/nvram get lan_netmask`
wandevs=`/bin/nvram get wandevs | cut -d= -f2 | cut -d" " -f1` # we only want one device here

mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *);;
        esac
    done
    echo "$nbits"
}

zero_bits() {
  let ip1="$(echo $1 | cut -d. -f1)"
  let ip2="$(echo $1 | cut -d. -f2)"
  let ip3="$(echo $1 | cut -d. -f3)"
  let ip4="$(echo $1 | cut -d. -f4)"

  let mask1="$(echo $2 | cut -d. -f1)"
  let mask2="$(echo $2 | cut -d. -f2)"
  let mask3="$(echo $2 | cut -d. -f3)"
  let mask4="$(echo $2 | cut -d. -f4)"

  let octet1="$ip1 & $mask1"
  let octet2="$ip2 & $mask2"
  let octet3="$ip3 & $mask3"
  let octet4="$ip4 & $mask4"

  echo $octet1.$octet2.$octet3.$octet4
}

cleanup_ip_routes()
{
  /usr/sbin/ip route del 0.0.0.0/1 via $route_vpn_gateway
  /usr/sbin/ip route del 128.0.0.0/1 via $route_vpn_gateway
  /usr/sbin/ip route del $remote_1 via $route_net_gateway
  ip=$(zero_bits $route_vpn_gateway $ifconfig_netmask)
  cidr=$(mask2cidr $ifconfig_netmask)
  /usr/sbin/ip route del $ip/$cidr dev $dev
}

emergency_cleanup_if_necessary()
{
  if [ -z "${script_type+xxx}" ] && [ -z "${dev+xxx}" ]; then
    . $openvpn_saved_variables
    script_type=down
    cleanup_ip_routes
  fi
}

save_env_variables()
{
   echo "dev=$dev" > $openvpn_saved_variables
   echo "route_vpn_gateway=$route_vpn_gateway" >> $openvpn_saved_variables
   echo "route_net_gateway=$route_net_gateway" >> $openvpn_saved_variables
   echo "ifconfig_netmask=$ifconfig_netmask" >> $openvpn_saved_variables
   echo "remote_1=$remote_1" >> $openvpn_saved_variables
}

add_dns()
{
  if [ ! -d $dns_dir ]; then mkdir -p $dns_dir; fi
  for optionname in `set | grep "^foreign_option_" | sed "s/^\(.*\)=.*$/\1/g"`
  do
    option=`eval "echo \\$$optionname"`
    if echo $option | grep "dhcp-option WINS "; then echo $option | sed "s/ WINS /=44,/" >> $dns_conf_file; fi
    if echo $option | grep "dhcp-option DNS"; then echo $option | sed "s/dhcp-option DNS/nameserver/" >> $dns_resolv_file; fi
    if echo $option | grep "dhcp-option DOMAIN"; then echo $option | sed "s/dhcp-option DOMAIN/search/" >> $dns_resolv_file; fi
  done
}

add_firewall_rules()
{
  /usr/sbin/iptables -I INPUT -i ${dev} -j ACCEPT
  /usr/sbin/iptables -I FORWARD -i ${dev} -j ACCEPT
  /usr/sbin/iptables -t nat -I POSTROUTING -s ${lan_ipaddr}/${lan_netmask} -o ${dev} -j MASQUERADE
}

save_firewall_rules()
{
  if [ ! -d $firewall_dir ]; then mkdir -p $firewall_dir; fi
  echo "/usr/sbin/iptables -I INPUT -i ${dev} -j ACCEPT" > $firewall_file
  echo "/usr/sbin/iptables -I FORWARD -i ${dev} -j ACCEPT" >> $firewall_file
  echo "/usr/sbin/iptables -t nat -I POSTROUTING -s ${lan_ipaddr}/${lan_netmask} -o ${dev} -j MASQUERADE" >> $firewall_file
  chmod 755 $firewall_file
}

delete_firewall_rules()
{
  /usr/sbin/iptables -D INPUT -i ${dev} -j ACCEPT
  /usr/sbin/iptables -D FORWARD -i ${dev} -j ACCEPT
  /usr/sbin/iptables -t nat -D POSTROUTING -s ${lan_ipaddr}/${lan_netmask} -o ${dev} -j MASQUERADE
}

clean_up()
{
  /bin/rm $firewall_file
  /bin/rm $dns_resolv_file
  /bin/rm $dns_conf_file
  /bin/rm $openvpn_saved_variables
}

emergency_cleanup_if_necessary

if [ $script_type == 'up' ]
then
  save_env_variables       
  add_dns
  add_firewall_rules
  save_firewall_rules

else # down script
  delete_firewall_rules
  clean_up
fi

/sbin/service dnsmasq restart

exit 0
