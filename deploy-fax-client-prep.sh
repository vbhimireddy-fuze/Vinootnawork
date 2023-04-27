#!/bin/bash

find_faxcfg () {
  if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -eq 0 ] ; then echo -e "Unable to detect fax.cfg as commetrex_fax_client is not running."; exit; fi
  FPID=$(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  FDIR=$(ls -l /proc/${FPID}/cwd 2>/dev/null | awk '{print $NF}')

  FAXCFG=${FDIR}/fax.cfg
  echo $FAXCFG
}

if [ $(whoami) != "root" ]
  then echo "Please run this script as root user"
  exit 1
fi

# They know they run it manually, it good to ask but....
# - this will break if you call it from another script
while true; do
  read -p 'This script will also restart fax client. Do you wish to proceed? Y/N? ' yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

#It's nice to ask but you can make in a different way:
# - ask for a paramater (filecfg)
# - if empty try the self discovery (very nice but I would avoid it, devs are strange they might change the config file name)
# verify that the file contains NUM_INCOMING_CHANNELS, if not is not a our config file exit
while true; do
  read -p 'Press A if you want this script automatically locate fax.cfg or B if you would like to manually input fax.cfg location: ' AB
  case $AB in
    [Aa] )
      faxcfg=$(find_faxcfg)
      if [[ "${faxcfg}" == *"Unable"* ]]; then 
        read -p "${faxcfg} Enter full fax.cfg location (example - /var/lib/fax.cfg): " faxcfg; 
      else 
        echo "Proceeding with ${faxcfg} - detected by this script."; fi
      break;;
    [Bb] )
      # If you ask them to write it you must verify if is correct
      while true; do
        read -p 'Enter full fax.cfg location (example - /var/lib/fax.cfg): ' faxcfg
        [ -f $faxcfg ] && break;; || echo "File not found"
      break;;
    * ) echo "Please choose A or B";;
  esac
done

#Better to check before 
if [ $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS | wc -l) -gt 1 ]
then
  echo "Your ${faxcfg} has multiple uncommented NUM_INCOMING_CHANNELS entries. Hence exiting..."
  exit
fi


echo "Current NUM_INCOMING_CHANNELS = $(grep -v '^#' ${faxcfg} | grep -i NUM_INCOMING_CHANNELS)"
#avoid it ask for a parameter (on/off/number) this will break if called from another script
# on is the old value/off is 0/num is the number of channels they want
read -p 'Enter number for NUM_INCOMING_CHANNELS (Enter 0  prior to any deployment activity or a desired number if you are restoring services): ' NIC


chown ipbx:ipbx /tmp/.fax.out && chmod u+w /tmp/.fax.out

echo "Currently $(whoami)"
sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and stopping faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh stop
EOF
#give more time to die 3 seconds is a bit short, more like 30
sleep 3 && echo "Switching back to $(whoami)"

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  kill -9 $(ps aux | grep commetrex_fax_client | grep -v grep | head -1 | awk '{print $2}')
  echo "Forcefully killed fax client and proceeding"
fi

#you lose the previous value
sed -i "/^NUM_INCOMING_CHANNELS/c\NUM_INCOMING_CHANNELS ${NIC}" ${faxcfg}

echo "Currently $(whoami)"
sudo -i -u ipbx bash << EOF
  echo "Switching now to \$(whoami) and starting faxclient"
  /apps/ipbx/commetrexfax/faxclientservices.sh start
EOF
sleep 3 && echo "Switching back to $(whoami)"


sleep 60

if [ $(ps aux | grep commetrex_fax_client | grep -v grep | wc -l) -gt 0 ]
then
  echo "Started commetrex_fax_client.."
  exit
fi

/apps/ipbx/commetrexfax/faxclientservices.sh status

#I'm not sure about the $? of this script. to be automated if needs an exit code
#if the line up fails you continue, the exit code is 0 (all good which is not)
# called from another script I need to know the exit code

#redundant
echo "Status of commetrex_fax_client:"
ps aux | grep commetrex_fax_client | grep -v grep


