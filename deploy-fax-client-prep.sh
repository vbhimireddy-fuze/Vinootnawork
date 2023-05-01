#!/bin/bash

function find_faxcfg() {
  if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -eq 0 ]
  then
    echo -e "Unable to detect fax.cfg as commetrex_fax_client is not running."
    exit
  fi
  FPID=$(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  FDIR=$(ls -l /proc/${FPID}/cwd 2>/dev/null | awk '{print $NF}')

  FAXCFG=${FDIR}/fax.cfg
  echo $FAXCFG
}

function repeat() {
  for i in  {1..120}; do echo -n "-"; done
  echo
}

function show_usage (){
  repeat
  printf "Usage:\n$0 -f [params] -c [params]\n"
  repeat
  printf "Options:\n"
  printf " -f|--file, full path where file.cfg is located. This accepts AUTO if you want to auto-detect the location.\n"
  printf " -c|--count, count of NUM_INCOMING_CHANNELS. This accepts 3 values - ON, OFF, number.\n"
  repeat
  printf "For example:\n   To auto-detect fax.cfg location and set NUM_INCOMING_CHANNELS to 0 use below command:\n\t$0 -f AUTO -c OFF\n"
  printf "   To manually enter fax.cfg location and set NUM_INCOMING_CHANNELS to the last known config, use below command:\n\t$0 -f /path/to/fax.cfg -c ON\n"
  printf "   To manually enter fax.cfg location and set NUM_INCOMING_CHANNELS to a desired number, say 75, use below command:\n\t$0 -f /path/to/fax.cfg -c 75\n"
  repeat
  exit 5
}

if [ $(whoami) != "root" ]
  then echo "Please run this script as root user"
fi

if [ "$#" -ne 4 ]; then show_usage; exit; fi

repeat 

while [ ! -z "$1" ]; do
  case "$1" in
     --file|-f)
         shift
         faxcfg_path=$1
         echo "File location entered: $1"
         ;;
     --count|-c)
         shift
         count=$1
         echo "NUM_INCOMING_CHANNELS count: $1"
         ;;
     *)
        show_usage
        ;;
  esac
shift
done

case $faxcfg_path in
  AUTO|Auto|auto)
    faxcfg=$(find_faxcfg)
    echo "Proceeding with ${faxcfg} - detected by this script.";;
  [/~]*)
    if [ -f $faxcfg_path ] ; then faxcfg=$faxcfg_path ; else echo "$faxcfg_path is non-existent; hence exiting"; exit; fi
    echo $faxcfg_path ;;
  *) 
    show_usage;;
esac

echo "Current NUM_INCOMING_CHANNELS = $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS)"

if [ $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS | wc -l) -gt 1 ]
then
  echo "Your ${faxcfg} has multiple uncommented NUM_INCOMING_CHANNELS entries. Hence exiting..."
  exit
fi

case $count in
  Off|OFF|off)
    repeat; echo "BEFORE:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
    sed -i -n 'p; /^NUM_INCOMING_CHANNELS/s/^/#PREP/p' ${faxcfg}
    sed -i '/^NUM_INCOMING_CHANNELS/c\NUM_INCOMING_CHANNELS 0' ${faxcfg}
    repeat; echo "AFTER SED OFF:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat ;;
  On|ON|on)
    repeat; echo "BEFORE:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
    sed -i '/NUM_INCOMING_CHANNELS.*0/d' ${faxcfg}
    sed -i '/NUM_INCOMING_CHANNELS/s/^#PREP//g' ${faxcfg}
    repeat; echo "AFTER SED ON WITH OLD NUM:"; grep NUM_INCOMING_CHANNELS ${faxcfg} ;;
  ''|*[!0-9]*)
    show_usage;;
  *)
    repeat; echo "BEFORE:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
    sed -i -n 'p; /^NUM_INCOMING_CHANNELS/s/^/#PREP/p' ${faxcfg}
    sed -i "/^NUM_INCOMING_CHANNELS/c\NUM_INCOMING_CHANNELS $count" ${faxcfg}
    repeat; echo "AFTER SED ON WITH NEW NUM:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat;;
esac

echo -e "$(repeat)\nWARNING: This script will also restart the commetrex_fax_client services running on this machine.\n$(repeat)"; sleep 2

chown ipbx:ipbx /tmp/.fax.out && chmod u+w /tmp/.fax.out

sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and stopping faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh stop >/tmp/f_shutdown.out 2>&1
EOF
sleep 3

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  kill -9 $(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  echo "Forcefully killed fax client and proceeding"
fi

sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and starting faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh start >/tmp/f_startup.out 2>&1
  ECODE=$?
EOF

sleep 10

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  echo "Started commetrex_fax_client.."
fi

/apps/ipbx/commetrexfax/faxclientservices.sh status

egrep -i error\|fail\|denied /tmp/f_startup.out || echo "NO ERRORS FOUND ON FAX SERVICES STARTUP LOGS"
rm -vf /tmp/f_s*.out

repeat

exit ${ECODE}
