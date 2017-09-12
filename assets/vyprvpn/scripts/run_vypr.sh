#!/bin/sh

(
ORIG_WEB_DIR=/www
USER_WEB_DIR=/www/user
CGI_DIR=/www/user/cgi-bin
VYPR_MOUNT_DIR=/tmp/var/vypr_mount
VYPR_DIR=/tmp/var/vyprvpn
VYPR_CUSTOM_JS=/tmp/var/vyprvpn/www/build/vyprvpn/js/firmware/tomato.js
VYPR_PAGES_JS=/tmp/var/vyprvpn/scripts/vypr_pages_js
APP_STATUS_FILE=/www/user/vyprvpn_app_status.html
APP_STATUS_FILE_TMP=/www/user/vyprvpn_app_status.tmp

output_app_state_for_UI()
{
  # we will write state to the tmp file first, then do a mv to the actual status file
  # we do this because the mv is atomic, but the write is not
  echo "{\"res\":\"OK\",\"data\":{\"status\":\"restarting\"}}" > $APP_STATUS_FILE_TMP
  /bin/mv $APP_STATUS_FILE_TMP $APP_STATUS_FILE
}

kill_vpn_processes()
{
  echo -n "Sending SIGTERM to VPN processes..."
  /bin/kill -SIGTERM "$(pidof openvpn)" >/dev/null 2>&1
  /bin/kill -SIGTERM "$(pidof pppd)" >/dev/null 2>&1
  /bin/kill -SIGTERM "$(pidof chameleon)" >/dev/null 2>&1
  echo "sent."
}

kill_old_cgi_processes()
{
  echo -n "Sending SIGTERM to old VyprVPN cgi processes..."
  /bin/kill -SIGTERM "$(pidof vyprvpn.cgi)" >/dev/null 2>&1
  echo "sent."
}

kill_watchdog()
{
  /bin/kill -SIGTERM "$(pidof watchdog.sh)" >/dev/null 2>&1
}

add_vypr_links_to_tomato_navigation()
{
  echo -n "Adding VyprVPN links to tomato webpages..."
  /bin/umount $ORIG_WEB_DIR/tomato.js
  /bin/rm -rf $VYPR_MOUNT_DIR
  /bin/mkdir -p $VYPR_MOUNT_DIR
  /bin/cp -f $ORIG_WEB_DIR/tomato.js $VYPR_MOUNT_DIR
  /bin/cat $VYPR_CUSTOM_JS >> $VYPR_MOUNT_DIR/tomato.js
  /bin/sed -i -f $VYPR_PAGES_JS $VYPR_MOUNT_DIR/tomato.js
  /bin/sed -i "/buf.push('<a href=\"' + a + '\" class=\"indent1/iif (m[1] == 'vyprvpn') a = 'user/vyprvpn-' + b; if (b.search('javascript') == -1 && a != '/') { a = '/' + a; }" $VYPR_MOUNT_DIR/tomato.js
  /bin/sed -i "/buf.push('<a href=\"' + a + '\" class=\"indent2/iif (m[1] == 'vyprvpn') a = 'user/vyprvpn-' + sm[1]; if (sm[1].search('javascript') == -1 && a != '/') { a = '/' + a; }" $VYPR_MOUNT_DIR/tomato.js
  /bin/sed -i "/buf.push('<a href=\"' + m\[1\]/ia = m[1]; if (a.search('javascript') == -1 && a != '/') { a = '/' + a; }" $VYPR_MOUNT_DIR/tomato.js
  /bin/sed -i -e "s/\(buf.push('<a href=\"' + \)m\[1\]/\1a/" $VYPR_MOUNT_DIR/tomato.js
  /bin/mount -o bind $VYPR_MOUNT_DIR/tomato.js $ORIG_WEB_DIR/tomato.js
  echo "added."
}

copy_vypr_pages_to_webserver_directory()
{
  echo -n "Copying VyprVPN webpages into $USER_WEB_DIR..."
  /bin/cp -r $VYPR_DIR/www/build/* $USER_WEB_DIR >/dev/null 2>&1
  echo "copied."
}

copy_vypr_cgi_to_cgi_bin()
{
  echo -n "Moving vyprvpn.cgi into $CGI_DIR..."
  /bin/mv $VYPR_DIR/vyprvpn.cgi $CGI_DIR >/dev/null 2>&1
  echo "copied."
}

set_library_load_path()
{
  export LD_LIBRARY_PATH=$VYPR_DIR
}

execute_vypr_daemon()
{
  echo -n "Starting VyprVPN daemon..."
  $VYPR_DIR/vyprvpn >/dev/null 2>&1 &
  echo "started."
}

output_app_state_for_UI
kill_vpn_processes
kill_old_cgi_processes
kill_watchdog
add_vypr_links_to_tomato_navigation
copy_vypr_pages_to_webserver_directory
copy_vypr_cgi_to_cgi_bin
set_library_load_path
execute_vypr_daemon

) &
