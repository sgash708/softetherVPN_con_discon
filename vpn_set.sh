#!/bin/sh -e

VPNPATH=/usr/local/vpnclient
VPNCLIENT=${VPNPATH}/vpnclient
VPNCMD=${VPNPATH}/vpncmd
SERVER="`route -n get sample-dns.softether.net | grep 'route to:' | awk '{print $3}'`"
# 自宅のゲートウェイに合わせて変更
# e.g.) 192.168.3.1
NEW_DEFROUTE="192.168.0.1"
NET_MASK="255.255.255.255"
VPNNAME="AC_SAMPLE"
VPNUP=`ps -ef | grep vpnclient | grep -v grep | wc -l`

case "$1" in
  start)
    if [ $VPNUP = 0 ]; then
      sudo -S ${VPNCLIENT} start
      sudo ${VPNCMD} << EOF
2
localhost
AccountConnect ${VPNNAME}
AccountStatusGet ${VPNNAME}
EOF

      # DHCPによるIPアドレスの取得
      sudo ipconfig set tap0 DHCP
      sleep 3
      CURRENT_DEFROUTE=`netstat -nr | grep -E 'default(.)*en0' | awk '{print $2}'`
      # 静的ルーティング追加
      sudo /sbin/route add -net $SERVER $CURRENT_DEFROUTE $NET_MASK
      # 既存デフォルトゲートウェイ削除
      sudo route -n delete default
      sleep 10
      sudo route add default $NEW_DEFROUTE
    else
      echo "VPN Client has already started."
      exit 1
    fi
    ;;
  stop)
    if [ $VPNUP = 0 ]; then
      echo "VPN client has already stoped."
      exit 1
    else
      ${VPNCMD} << EOF
2
localhost
AccountDisconnect ${VPNNAME}
AccountStatusGet ${VPNNAME}
EOF

      sudo -S ${VPNCLIENT} stop
      sleep 1
      NEW_DEFROUTE=`netstat -nr | grep -E "${SERVER}(.)*en0" | awk '{print $2}'`
      sudo /sbin/route -n delete -net $SERVER $NEW_DEFROUTE $NET_MASK
      sleep 1
      sudo route add default $NEW_DEFROUTE
    fi
    ;;
  restart)
    $0 stop
    sleep 3
    $0 start
    ;;
  *)
    echo "Usage: vpn.sh {start|stop|restart}"
    exit 1
    ;;
esac
