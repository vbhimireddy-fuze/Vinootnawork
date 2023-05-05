#!/bin/bash

FAXOUT_FILE="/tmp/.fax.out"
rm -f $FAXOUT_FILE
touch $FAXOUT_FILE

NAME=FAX_SERVICES

# change directory to the path of this script, regardless of where you are called from
#echo "Changing directory to $(dirname "$0")" > $FAXOUT_FILE
cd "$(dirname "$0")"

# Error returns
ERROR_NO_ERROR=0
ERROR_WARN=1
ERROR_ERROR=2

function exitProgram {
    local __exitCode=$1

    local __OUT=`cat $FAXOUT_FILE | tr '\n' ',' | sed 's/,$//g'`
    echo "$__exitCode $NAME - $__OUT"

    exit $__exitCode
}

if [ $# != 1 ];then
    echo "Usage: ./faxclientservices.sh <command>" >> $FAXOUT_FILE
    echo "  <command> is one of:" >> $FAXOUT_FILE
    echo "    start              Starts Commetrex Bladeware services and 8x8 Commetrex Fax Client" >> $FAXOUT_FILE
    echo "    restart            Restarts Commetrex Bladeware services and 8x8 Commetrex Fax Client" >> $FAXOUT_FILE
    echo "    stop               Stops Commetrex Bladeware services and 8x8 Commetrex Fax Client" >> $FAXOUT_FILE
    echo "    check              Checks that all processess are running" >> $FAXOUT_FILE
    echo "  By default, this script will look for Commetrex services files under the directory /usr/local/Commetrex" >> $FAXOUT_FILE
    echo "  If you have installed Commetrex services in a different directory, put that location in the file" >> $FAXOUT_FILE
    echo "  commetrexfax.home, where commetrexfax.home is in the same directory as this script.  An example commetrexfax.home would be:" >> $FAXOUT_FILE
    echo "  /usr/local/Commetrex.alternate.location" >> $FAXOUT_FILE
    echo "  This script has multiple return codes, depending on the error:" >> $FAXOUT_FILE
    echo "  0 -> no error" >> $FAXOUT_FILE
    echo "  1 -> warning" >> $FAXOUT_FILE
    echo "  2 -> error" >> $FAXOUT_FILE
    exitProgram $ERROR_ERROR
fi

# enable core files
ulimit -c unlimited

FAX_CLIENT_PROGRAM=commetrex_fax_client
COMMETREXFAX_HOME=`pwd`
PATH=$COMMETREXFAX_HOME:$PATH

COMMETREXFAX_PID="$COMMETREXFAX_HOME/commetrexfax.pid"
COMMETREX_SERVICES_HOME=/usr/local/Commetrex
COMMETREX_SERVICES_LOCATION_FILE=commetrexfax.home
COMMETREX_SERVICES_START_TIMEOUT=180
FAX_CLIENT_START_TIMEOUT=30

if [ -e $COMMETREX_SERVICES_LOCATION_FILE ];then
    COMMETREX_SERVICES_HOME=$(cat $COMMETREX_SERVICES_LOCATION_FILE)
fi

action=$1

function checkProcess {
    local __processName="$1"
    #echo "checking for $__processName"

    __pidStatus=0

    checkPid=$(ps aux | grep "$__processName" | grep -v grep | tr -s " " | cut -d " " -f 2)
    #echo "checkPid = $checkPid"
    if [ -z "$checkPid" ];then
	__pidStatus=1
    else
	kill -0 $checkPid
	if [ $? != 0 ];then
	    __pidStatus=1
	else
	    # pid is active - see if it's in zombie state
	    pidStatus=$(ps aux | grep "$__processName" | grep -v grep | tr -s " " | cut -d " " -f 8)
	    if [ $pidStatus == Z ]; then
		__pidStatus=2
	    fi
	fi
    fi
    return $__pidStatus
}

# check processes active functions

function checkCommetrexProcesses {

    local __processesOk=0
    local __processArray=(otfkern otfadmin otfgm otfconn otftdc_h100 otfrsm_sip otfrsm_omsigdetgen otfrsm_omfax otfscr)

    local __processStatus=0

    for __processToCheck in "${__processArray[@]}"; do
	#echo "checkCommetrexProcesses __processToCheck is $__processToCheck"
	checkProcess "$__processToCheck"

	__processStatus=$?

	if [ $__processStatus != 0 ]; then
	    if [ $__processStatus == 1 ];then
		echo "$__processToCheck does not exist" >> $FAXOUT_FILE
	    fi
	    if [ $__processStatus == 2 ];then
		echo "$__processToCheck is in zombie state" >> $FAXOUT_FILE
	    fi
	    __processesOk=1
	else
	    echo "$__processToCheck is ok" >> $FAXOUT_FILE
	fi
    done

    return $__processesOk
}

function checkFaxClientProcess {
    local __processesOk=0
    local __processArray=(commetrex_fax_client)

    for __processToCheck in "${__processArray[@]}"; do
	#echo "checkFaxClientProcess __processToCheck is $__processToCheck"
	checkProcess "$__processToCheck"

	__processStatus=$?

	if [ $__processStatus != 0 ]; then
	    if [ $__processStatus == 1 ];then
		echo "$__processToCheck does not exist" >> $FAXOUT_FILE
	    fi
	    if [ $__processStatus == 2 ];then
		echo "$__processToCheck is in zombie state" >> $FAXOUT_FILE
	    fi
	    __processesOk=1
	else
	    echo "$__processToCheck is ok" >> $FAXOUT_FILE
	fi
    done

    return $__processesOk
}

function checkAllProcesses {
    local __allProcessesActive=0

    checkCommetrexProcesses
    local __allCommetrexProcessesActive=$?

    if [ $__allCommetrexProcessesActive != 0 ];then
	__allProcessesActive=1
    fi

    checkFaxClientProcess
    local __allFaxClientProcessesActive=$?
    if [ $__allFaxClientProcessesActive != 0 ];then
	__allProcessesActive=1
    fi

    return $__allProcessesActive
}

# check processes stopped section

function checkCommetrexProcessesStopped {

    local __processesStopped=0
    local __processArray=(otfkern otfadmin otfgm otfconn otftdc_h100 otfrsm_sip otfrsm_omsigdetgen otfrsm_omfax otfscr)

    local __processStatus=0

    for __processToCheck in "${__processArray[@]}"; do
	#echo "checkCommetrexProcessesStopped __processToCheck is $__processToCheck"
	checkProcess "$__processToCheck"

	__processStatus=$?

	if [ $__processStatus != 1 ]; then
	    if [ $__processStatus == 0 ];then
		echo "$__processToCheck is still running" >> $FAXOUT_FILE
	    fi
	    if [ $__processStatus == 2 ];then
		echo "$__processToCheck is in zombie state" >> $FAXOUT_FILE
	    fi
	    __processesStopped=1
	fi
    done

    return $__processesStopped
}

function checkFaxClientProcessStopped {
    local __processesStopped=0
    local __processArray=(commetrex_fax_client)

    local __processStatus=0

    for __processToCheck in "${__processArray[@]}"; do
	#echo "checkFaxClientProcessStopped __processToCheck is $__processToCheck"
	checkProcess "$__processToCheck"

	__processStatus=$?

	if [ $__processStatus != 1 ]; then
	    if [ $__processStatus == 0 ];then
		echo "$__processToCheck is still running" >> $FAXOUT_FILE
	    fi
	    if [ $__processStatus == 2 ];then
		echo "$__processToCheck is in zombie state" >> $FAXOUT_FILE
	    fi
	    __processesStopped=1
	fi
    done

    return $__processesStopped
}

function checkAllProcessesStopped {
    local __allProcessesStopped=0

    # check if fax client is stopped
    checkFaxClientProcessStopped
    local __allFaxClientProcessesStopped=$?

    if [ $__allFaxClientProcessesStopped != 0 ];then
	__allProcessesStopped=1
    fi

    checkCommetrexProcessesStopped
    local __allCommetrexProcessesStopped=$?

    if [ $__allCommetrexProcessesStopped != 0 ];then
	__allProcessesStopped=1
    fi

    return $__allProcessesStopped
}

# stop processes functions

function stopCommetrexProcesses {
    pushd ${COMMETREX_SERVICES_HOME}/otf/bin 2>&1 > /dev/null
    ./stopotf.sh 2>&1 /dev/null
    sleep 10
    popd 2>&1 > /dev/null
}


function stopFaxClientProcess {
    # get the pid for the fax client
    local checkPid=$(ps aux | grep $FAX_CLIENT_PROGRAM | grep -v grep | tr -s " " | cut -d " " -f 2)
    local startTime
    local faxClientStopped=false
    local faxClientTimeout=10
    local shutdownClientPollingInterval=1

    if [ -n "$checkPid" ];then
	echo "Stopping fax client with PID=$checkPid" >> $FAXOUT_FILE
	kill -s INT $checkPid
	# VOAPSRV-699 -> wait for client shutdown a bit; if it does not shut down gracefully, then use kill -9
	startTime=$SECONDS
	while [ $(( SECONDS - startTime )) -le $faxClientTimeout ];do
	    sleep $shutdownClientPollingInterval
            checkPid=$(ps aux | grep $FAX_CLIENT_PROGRAM | grep -v grep | tr -s " " | cut -d " " -f 2)
	        if [ -z $checkPid ];then
		    echo "Fax client stopped normally with kill -s INT in "$(( SECONDS - startTime ))" seconds" >> $FAXOUT_FILE
		    faxClientStopped=true
                    break
		fi
	done

	if [ $faxClientStopped == false ];then
	    echo "Using kill -9 to stop fax client after $faxClientTimeout seconds" >> $FAXOUT_FILE
	    kill -9 $checkPid
	fi
    fi
}

function stopAllProcesses {
    # when stopping processes, shut down the client, then shut down commetrex
    stopFaxClientProcess
    stopCommetrexProcesses
}

# start process functions

function startCommetrexProcesses {
    pushd ${COMMETREX_SERVICES_HOME}/otf/bin
    ./startotf.sh 2>&1 /dev/null
    sleep 3
    popd
}

function startFaxClientProcess {
    #./commetrexfaxclient.sh start
    touch "$COMMETREXFAX_HOME"/commetrexfax.out
    # When redirecting to the commetrexfax.out, we have encountered out of disk space issues when Commetrex hits an access issue with the LOGS dir (which Commetrex creates).
    # It floods commetrexfax.out with messages and will consume all available disk space
    #nohup "$FAX_CLIENT_PROGRAM" 2>&1 > "$COMMETREXFAX_HOME"/commetrexfax.out &
    nohup "$FAX_CLIENT_PROGRAM" 2>&1 > /dev/null &

    if [ ! -z "$COMMETREXFAX_PID" ]; then
        echo $! > $COMMETREXFAX_PID
	echo "Commetrex fax client pid: `cat $COMMETREXFAX_PID`" >> $FAXOUT_FILE
    fi

    # wait a bit to start
    sleep 3
}

function actionStart {
    local __actionStartReturn=0
    commetrexServicesElapsedTime=0
    faxClientServicesElapsedTime=0

    checkAllProcessesStopped
    allProcessesStopped=$?
    if [ $allProcessesStopped != 0 ];then
	echo "ERROR: processes are still running.  Run ./faxclientservices.sh stop to stop them." >> $FAXOUT_FILE
	__actionStartReturn=1
    else
	# Start Commetrex services.  The Commetrex services MUST be started BEFORE the fax client
	echo "Starting Commetrex Bladeware services and Fax Client" >> $FAXOUT_FILE
	commetrexServicesStartTimeout=$COMMETREX_SERVICES_START_TIMEOUT
	commetrexServicesStartTime=$SECONDS
	commetrexProcessesStarted=0
	startCommetrexProcesses
	while [ $(( SECONDS - commetrexServicesStartTime )) -le $commetrexServicesStartTimeout ]
	do
	    checkCommetrexProcesses
	    commetrexProcessesStarted=$?
	    commetrexServicesElapsedTime=$(( SECONDS - startTime ))
	    if [ $commetrexProcessesStarted != 0 ];then
		echo "Commetrex processes have been starting for $commetrexServicesElapsedTime seconds" >> $FAXOUT_FILE
	    else
		echo "SUCCESS: all Commetrex processes have started.  Time taken was $commetrexServicesElapsedTime seconds" >> $FAXOUT_FILE
		break
	    fi
	    sleep 5
	done
	if [ $commetrexProcessesStarted != 0 ];then
	    echo "ERROR: could not start all Commetrex processes in $commetrexServicesElapsedTime seconds." >> $FAXOUT_FILE
	    __actionStartReturn=1
	else
	    # Start the fax client.  The fax client MUST be started AFTER the Commetrex Services
	    faxClientProcessesStarted=0
	    faxClientServicesStartTimeout=$FAX_CLIENT_START_TIMEOUT
	    faxClientServicesStartTime=$SECONDS

	    # wait a little bit
	    sleep 3

	    startFaxClientProcess
	    while [ $(( SECONDS - faxClientServicesStartTime )) -le $faxClientServicesStartTimeout ]
	    do
		checkFaxClientProcess
		faxClientProcessesStarted=$?
		faxClientServicesElapsedTime=$(( SECONDS - faxClientServicesStartTime ))
		if [ $faxClientProcessesStarted != 0 ];then
		    echo "Fax client has been starting for $faxClientServicesElapsedTime seconds" >> $FAXOUT_FILE
		else
		    echo "SUCCESS: fax client has started.  Time taken was $faxClientServicesElapsedTime seconds" >> $FAXOUT_FILE
		    totalRestartTime=$(( commetrexServicesElapsedTime + faxClientServicesElapsedTime ))
		    echo "Total time taken to start services was $totalRestartTime seconds" >> $FAXOUT_FILE
		    break
		fi
		sleep 5
	    done
	    if [ $faxClientProcessesStarted != 0 ];then
		echo "ERROR: could not start fax client in $faxClientServicesStartTimeout seconds." >> $FAXOUT_FILE
		__actionStartReturn=1
	    fi
	fi
    fi

    return $__actionStartReturn
}

# start main program
if [ $action == start ];then
    actionStart
    actionStartReturn=$?
    if [ $actionStartReturn != 0 ];then
	exitProgram $ERROR_ERROR
    else
	echo "Commetrex Services and Fax Client started." >> $FAXOUT_FILE
    fi    
elif [ $action == restart ];then
    # stop all processes
    stopAllProcesses
    checkAllProcessesStopped
    allProcessesStopped=$?
    if [ $allProcessesStopped != 0 ];then
	echo "ERROR: some or all processes did not stop.  Something is wrong.  You will have to manually kill processes." >> $FAXOUT_FILE
	exitProgram $ERROR_ERROR
    fi

    # wait just a little bit
    sleep 10

    actionStart
    actionStartReturn=$?
    if [ $actionStartReturn != 0 ];then
	exitProgram $ERROR_ERROR
    else
	echo "SUCCESS: Commetrex Services and Fax Client started." >> $FAXOUT_FILE
    fi    

elif [ $action == safe-restart ];then

    #Wait if check_mk stops
    while ps aux | grep -i check_mk | grep -q -v grep
    do
        sleep 1
    done
    
    sleep .5
    ps aux | grep -i check_mk | grep -v grep || echo "CHECK_MK NOT RUNNING"

    # stop all processes
    stopAllProcesses
    checkAllProcessesStopped
    allProcessesStopped=$?
    if [ $allProcessesStopped != 0 ];then
        echo "ERROR: some or all processes did not stop.  Something is wrong.  You will have to manually kill processes." >> $FAXOUT_FILE
        exitProgram $ERROR_ERROR
    fi

    # wait just a little bit
    sleep 10

    actionStart
    actionStartReturn=$?
    if [ $actionStartReturn != 0 ];then
        exitProgram $ERROR_ERROR
    else
        echo "SUCCESS: Commetrex Services and Fax Client started." >> $FAXOUT_FILE
    fi   
 
elif [ $action == stop ];then

    stopAllProcesses
    checkAllProcessesStopped
    allProcessesStopped=$?
    if [ $allProcessesStopped != 0 ];then
	echo "Some or all processes did not stop.  Something is wrong.  You will have to manually kill processes." >> $FAXOUT_FILE
	exitProgram $ERROR_ERROR
    else
	echo "Commetrex Services and Fax Client stopped." >> $FAXOUT_FILE
    fi
elif [ $action == check ];then
    checkAllProcesses
    allProcessesRunning=$?
    if [ $allProcessesRunning != 0 ];then
	echo "Not all processes are running." >> $FAXOUT_FILE
	exitProgram $ERROR_ERROR
    else
	# check for Commetrex channel problems
	count=$(grep -c "error:Error_ECTF_OutOfService suberror:Error_ECTF_NoDeviceAvailable" fax_current.log)
	if [ $count != 0 ];then
	    echo "Commetrex channel problem.  You should restart fax client services" >> $FAXOUT_FILE
	    exitProgram $ERROR_ERROR
	fi
    fi
fi

exitProgram $ERROR_NO_ERROR
