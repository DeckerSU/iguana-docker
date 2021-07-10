#!/bin/bash
set -e

# create dummy KMD and assetchains .conf inside docker container
# with username and password, to allow iguana use correct credentials.
# DEFAULT_RPC_USERNAME / DEFAULT_RPC_PASSWORD env variables must
# correspond real daemons rpc user/pass on docker host.

MYIP=$(ip -4 addr show eth0 | grep -Po 'inet \K[\d.]+')
DOCKER_HOST_IP=172.17.0.1

iptables -F && iptables -t nat -F
sysctl -w net.ipv4.conf.eth0.route_localnet=1
# make sure all outgoing packets have the main client host's ip address
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source $MYIP

if [ ! -z "$DEFAULT_RPC_USERNAME" ] && [ ! -z "$DEFAULT_RPC_PASSWORD" ]
then
  mkdir $HOME/.komodo
  # https://tldp.org/LDP/abs/html/here-docs.html
  # https://stackoverflow.com/questions/2953081/how-can-i-write-a-heredoc-to-a-file-in-bash-script
  # cat << until_it_ends | tee $HOME/.komodo/komodo.conf
  cat << until_it_ends > $HOME/.komodo/komodo.conf
  # dummy config for iguana
  rpcuser=${DEFAULT_RPC_USERNAME}
  rpcpassword=${DEFAULT_RPC_PASSWORD}
  rpcport=7771
until_it_ends
  # test notarized assetchain
  test_ac_name=DECKER
  mkdir -p $HOME/.komodo/${test_ac_name}
  cat << until_it_ends > $HOME/.komodo/${test_ac_name}/${test_ac_name}.conf
  # dummy config for iguana
  rpcuser=${DEFAULT_RPC_USERNAME}
  rpcpassword=${DEFAULT_RPC_PASSWORD}
  rpcport=49332
until_it_ends


  # let's try to fool the client and DNAT a connection to the outside world
  iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 7771 -j DNAT --to-destination ${DOCKER_HOST_IP}:7771 -m comment --comment "KMD rpc redir"
  iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 49332 -j DNAT --to-destination ${DOCKER_HOST_IP}:49332 -m comment --comment "DECKER rpc redir"

  readarray -t kmd_coins < <(cat $HOME/dPoW/iguana/assetchains.json | jq -r '[.[].ac_name] | join("\n")')
  for i in "${kmd_coins[@]}"
  do
    # https://unix.stackexchange.com/questions/360540/append-to-a-pipe-and-pass-on
    coinfile=$(echo $i | { tr '[:upper:]' '[:lower:]' | tr -d '\n'; echo "_7776"; })
    coinfile="$HOME/dPoW/iguana/coins/${coinfile}"
    coininfo=$(cat ${coinfile} | grep -Po "\-\-data\s*\"\K.*(?=\")" | sed 's/\\\"/\"/g' | sed 's/\${HOME\#\"\/\"}\///')
    rpcport=$(echo $coininfo | jq .rpc)
    mkdir -p $HOME/.komodo/$i
    # cat << until_it_ends | tee $HOME/.komodo/$i/$i.conf
    cat << until_it_ends > $HOME/.komodo/$i/$i.conf
    # dummy config for iguana
    rpcuser=${DEFAULT_RPC_USERNAME}
    rpcpassword=${DEFAULT_RPC_PASSWORD}
    rpcport=${rpcport}
until_it_ends
    iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport ${rpcport} -j DNAT --to-destination ${DOCKER_HOST_IP}:${rpcport} -m comment --comment "$i rpc redir"
  done
fi

# default behaviour is to launch iguana
if [[ -z ${1} ]]; then
  echo "Starting iguana..."
  cd /root/dPoW/iguana
  ./m_notary_docker_test
  sleep 1
  # https://docs.docker.com/config/containers/multi-service_container/
  while sleep 60; do
    ps aux |grep iguana |grep -q -v grep
    IGUANA_STATUS=$?
    if [ $IGUANA_STATUS -ne 0 ]; then
      echo "Iguana has already exited."
      exit 1
    fi
  done
else
  exec "$@"
fi