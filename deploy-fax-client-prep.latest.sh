#!/bin/bash

find_faxcfg() {
  if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -eq 0 ] ; then echo -e "Unable to detect fax.cfg as commetrex_fax_client is not running."; exit; fi
  FPID=$(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  FDIR=$(ls -l /proc/${FPID}/cwd 2>/dev/null | awk '{print $NF}')

  FAXCFG=${FDIR}/fax.cfg
  echo $FAXCFG
}

repeat() {
  for i in  {1..75}; do echo -n "#"; done
  echo
}

if [ $(whoami) != "root" ]
  then echo "Please run this script as root user"
fi

while true; do
  read -p 'This script will also restart fax client. Do you wish to proceed? Y/N? ' yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

while true; do
  read -p 'Press A if you want this script automatically locate fax.cfg or B if you would like to manually input fax.cfg location: ' AB
  case $AB in
    [Aa] )
      faxcfg=$(find_faxcfg)
      if [[ "${faxcfg}" == *"Unable"* ]]; then read -p "${faxcfg} Enter full fax.cfg location (example - /var/lib/fax.cfg): " faxcfg; else echo "Proceeding with ${faxcfg} - detected by this script."; fi
      break;;
    [Bb] )
      read -p 'Enter full fax.cfg location (example - /var/lib/fax.cfg): ' faxcfg
      break;;
    * ) echo "Please choose A or B";;
  esac
done


echo "Current NUM_INCOMING_CHANNELS = $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS)"
#read -p 'Enter number for NUM_INCOMING_CHANNELS (Enter 0  prior to any deployment activity or a desired number if you are restoring services): ' NIC

if [ $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS | wc -l) -gt 1 ]
then
  echo "Your ${faxcfg} has multiple uncommented NUM_INCOMING_CHANNELS entries. Hence exiting..."
  exit
fi

while true; do
  read -p 'Enter 0 to set incoming channel to zero. Or enter R to revert to the previous number: ' NIC
  case $NIC in
    0 )
      repeat; echo "BEFORE:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
      sed -i -n 'p; /^NUM_INCOMING_CHANNELS/s/^/#PREP/p' ${faxcfg}
      sed -i '/^NUM_INCOMING_CHANNELS/c\NUM_INCOMING_CHANNELS 0' ${faxcfg}
      repeat; echo "AFTER SED:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
      break;;
    [Rr] )
      repeat; echo "BEFORE:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
      sed -i '/NUM_INCOMING_CHANNELS.*0/d' ${faxcfg}
      sed -i '/NUM_INCOMING_CHANNELS/s/^#PREP//g' ${faxcfg}
      repeat; echo "AFTER SED:"; grep NUM_INCOMING_CHANNELS ${faxcfg}; repeat
      break;;
    * ) echo "Enter 0 or R";;
  esac
done

chown ipbx:ipbx /tmp/.fax.out && chmod u+w /tmp/.fax.out

echo "Currently $(whoami)"
sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and stopping faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh stop
EOF
sleep 3 && echo "Switching back to $(whoami)"

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  kill -9 $(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  echo "Forcefully killed fax client and proceeding"
fi

echo "Currently $(whoami)"
sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and starting faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh start >/tmp/startup.out 2>&1
EOF
sleep 3 && echo "Switching back to $(whoami)"

sleep 120

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  echo "Started commetrex_fax_client.."
fi

/apps/ipbx/commetrexfax/faxclientservices.sh status

echo "Status of commetrex_fax_client:"
ps aux | grep commetrex_fax_client | grep -v grep

grep -i error /tmp/startup.out || echo "NO ERRORS ON STARTUP"
rm -f /tmp/startup.out
