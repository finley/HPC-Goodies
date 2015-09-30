#!/bin/bash
#
# 2014.02.25 Brian Elliott Finley <bfinley@lenovo.com>
#   - created
#

TAIL=$(which tail)
SEQ=$(which seq)
C1EUTIL=$(which c1eutil)
LOGGER=$(which logger)
SET_DMA_LATENCY=$(which set_dma_latency)
cpu_map_cache_FILE="/var/cache/hpc-goodies/cpu_map_cache.db"

acpi_cpufreq_SCALING_AVAILABLE_FREQUENCIES_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
SCALING_DRIVER_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
INTEL_PSTATE_NO_TURBO_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
CPUINFO_MAX_FREQ_file="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
CPUINFO_MIN_FREQ_file="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"

########################################################################
#
#   BEGIN functions
#
get_SCALING_DRIVER() {
    if [ ! -e $SCALING_DRIVER_file ]; then
        modprobe acpi_cpufreq
            # none loaded yet -- let's load our preferred driver
    fi

    if [ -e $SCALING_DRIVER_file ]; then
        my_SCALING_DRIVER=$(cat $SCALING_DRIVER_file)
            #
            #   Possible scaling drivers as of 2015.09.07:
            #
            #   intel_pstate
            #   acpi-cpufreq
            #
    else
        my_SCALING_DRIVER=UNKNOWN
    fi
}


get_TURBO_HW_STATE() {

    get_SCALING_DRIVER

    if [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then

        if [ -e $INTEL_PSTATE_NO_TURBO_file ]; then
            my_TURBO_HW_STATE=On
        else
            my_TURBO_HW_STATE=Off
        fi

        get_MAX_FREQ_AVAILABLE
        my_TURBO_FREQ=$my_MAX_FREQ_AVAILABLE


    elif [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        grep -q 010 $acpi_cpufreq_SCALING_AVAILABLE_FREQUENCIES_file 
        if [ $? -eq 0 ]; then
            my_TURBO_HW_STATE=On 
            my_TURBO_FREQ=$(cat $acpi_cpufreq_SCALING_AVAILABLE_FREQUENCIES_file | awk '{print $1}')
        else
            my_TURBO_HW_STATE=Off
        fi
    fi
}


get_TURBO_OS_STATE() {

    get_TURBO_HW_STATE

    if [ "$my_TURBO_HW_STATE" = "On" ]; then

        if [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then

            # 0 is the value in this file if turbo is engaged
            grep -qw ^0 $INTEL_PSTATE_NO_TURBO_file
            if [ $? -eq 0 ]; then
                my_TURBO_OS_STATE="On"
            else
                my_TURBO_OS_STATE="Off"
            fi

        elif [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

            get_SCALING_MAX_FREQ_state
            my_TURBO_OS_STATE=$(echo "$my_SCALING_MAX_FREQ_state" | grep 010 | awk '{print $1 " cores engaged"}')
            if [ ! -z "$my_TURBO_OS_STATE" ]; then
                my_TURBO_OS_STATE="On -- $my_TURBO_OS_STATE"
            else
                # Nothing there, must not have any engaged -BEF-
                my_TURBO_OS_STATE="Off"
            fi
        fi

    else
        my_TURBO_OS_STATE="Off"
    fi
}


get_SCALING_GOVERNOR() {
    my_SCALING_GOVERNOR=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores using /'
        )
}


get_SCALING_MAX_FREQ_state() {
    my_SCALING_MAX_FREQ_state=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores at /'
        )
}

get_SCALING_MIN_FREQ_state() {
    my_SCALING_MIN_FREQ_state=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores at /'
        )
}

get_MAX_FREQ_AVAILABLE() {
    my_MAX_FREQ_AVAILABLE=$(cat $CPUINFO_MAX_FREQ_file)
}


get_MIN_FREQ_AVAILABLE() {
    my_MIN_FREQ_AVAILABLE=$(cat $CPUINFO_MIN_FREQ_file)
}


get_ACTIVE_REAL_AND_HYPERTHREADING_CORES() {
    my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_LIST=$(
        /bin/ls /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | sed -e 's/.*cpu\/cpu//' -e 's/\/.*/ /' \
        | tr -d '\n' \
        )
}


get_ACTIVE_REAL_CORES() {

    get_ACTIVE_REAL_AND_HYPERTHREADING_CORES

    my_REGEX=$(echo $my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_LIST | sed -e 's/ /|/g' -e 's/|$//')

    my_ACTIVE_REAL_CORES_LIST=$(echo  $cached_CORE_TOTAL_REAL_CORES_LIST | tr ' ' '\n' | egrep    -w "($my_REGEX)")
    my_ACTIVE_REAL_CORES_COUNT=$(echo $cached_CORE_TOTAL_REAL_CORES_LIST | tr ' ' '\n' | egrep -c -w "($my_REGEX)")
}


get_ACTIVE_HYPERTHREADING_CORES() {

    get_ACTIVE_REAL_AND_HYPERTHREADING_CORES

    my_REGEX=$(echo $my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_LIST | sed -e 's/ /|/g' -e 's/|$//')
    
    my_ACTIVE_HYPERTHREADING_CORES_LIST=$(echo  $cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST | tr ' ' '\n' | egrep    -w "($my_REGEX)")
    my_ACTIVE_HYPERTHREADING_CORES_COUNT=$(echo $cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST | tr ' ' '\n' | egrep -c -w "($my_REGEX)")
}


get_SOCKETS() {
    my_SOCKETS_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id  | sort -u)
    my_SOCKETS_COUNT=$(echo "$my_SOCKETS_LIST" | grep . | wc -l)
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l

    for socket in $my_SOCKETS_LIST
    do
        my_CORES_BY_SOCKET[$socket]=$(grep -l $socket /sys/devices/system/cpu/cpu*/topology/physical_package_id | sed -e 's/.*cpu\/cpu//' -e 's/\/.*/ /' | tr -d '\n')

        # trim space off the end
        my_CORES_BY_SOCKET[$socket]=$(echo ${my_CORES_BY_SOCKET[$socket]} | sed -r -e 's/^ +//' -e 's/ +$//')
    done

}


get_TOTAL_REAL_AND_HYPERTHREADING_CORES() {
    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT=$(( $(/bin/ls /sys/devices/system/cpu/cpu*/online | grep . | wc -l) + 1 ))
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l
    
    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST=$(/bin/ls /sys/devices/system/cpu/cpu*/online | sed -e 's/.*cpu\/cpu//' -e 's/\/.*/ /' | tr -d '\n')
    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST=$(echo "0 $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST" | sed -r -e 's/^ +//' -e 's/ +$//')
}


get_TOTAL_HYPERTHREADING_CORES() {

    get_TOTAL_REAL_AND_HYPERTHREADING_CORES
    get_TOTAL_REAL_CORES

    my_TOTAL_HYPERTHREADING_CORES_COUNT=$(( $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT - $my_TOTAL_REAL_CORES_COUNT ))
}


get_TOTAL_REAL_CORES() {
    get_SOCKETS
    my_CORES_PER_SOCKET=$(grep 'cpu cores' /proc/cpuinfo | sort -u | awk '{print $NF}')
    my_TOTAL_REAL_CORES_COUNT=$(( $my_SOCKETS_COUNT * $my_CORES_PER_SOCKET ))
}


get_CORE_OFFLINE() {
	my_CORE_OFFLINE_COUNT=$(grep -w 0 /sys/devices/system/cpu/cpu*/online | grep . | wc -l)
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l
	my_CORE_OFFLINE_LIST=$(grep -w 0 /sys/devices/system/cpu/cpu*/online)
}


get_HYPERTHREADING_STATE() {
  
	get_ACTIVE_HYPERTHREADING_CORES
    if [ "$my_ACTIVE_HYPERTHREADING_CORES_COUNT" -eq "0" ]; then
        my_HYPERTHREADING_OS_STATE=Off
    else
        my_HYPERTHREADING_OS_STATE=On
    fi

    get_TOTAL_HYPERTHREADING_CORES
    if [ "$my_TOTAL_HYPERTHREADING_CORES_COUNT" -eq "0" ]; then
        my_HYPERTHREADING_HW_STATE=Off
    else
        my_HYPERTHREADING_HW_STATE=On
    fi
}


set_HYPERTHREADING_ON() {

    get_ACTIVE_REAL_CORES

    for core in $my_ACTIVE_REAL_CORES_LIST
    do
        sibling=${cached_THREAD_SIBLINGS_BY_CORE[$core]}
        if [ $sibling -ne 0 ]; then
            echo -n 1 > /sys/devices/system/cpu/cpu${sibling}/online
        fi
        
    done
}


set_ALL_REAL_and_HYPERTHREADING_CORES_on() {
    
    for core in /sys/devices/system/cpu/cpu*/online
    do
        echo -n 1 > $core
    done
}


set_ALL_HYPERTHREADING_CORES_on() {
    
    for core in $cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST
    do
        if [ $core -ne 0 ]; then
            echo -n 1 > /sys/devices/system/cpu/cpu${core}/online
        fi
    done
}


set_ALL_REAL_CORES_on() {
    
    for core in $cached_CORE_TOTAL_REAL_CORES_LIST
    do
        if [ $core -ne 0 ]; then
            echo -n 1 > /sys/devices/system/cpu/cpu${core}/online
        fi
    done
}



set_HYPERTHREADING_OFF() {

	get_ACTIVE_HYPERTHREADING_CORES

    for core in $my_ACTIVE_HYPERTHREADING_CORES_LIST
    do
        # turn it off
        echo -n 0 > /sys/devices/system/cpu/cpu${core}/online
    done
}


set_HYPERTHREADING_STATE() {

    echo $USE_HYPERTHREADING | egrep -q -i '(yes|on|enabled|engaged)'
    if [ $? -eq 0 ]; then
        set_HYPERTHREADING_ON
    else
        set_HYPERTHREADING_OFF
    fi
}


get_C_STATE_LIMIT() {
    my_C_STATE_LIMIT=$(ps -A -o command | grep -v grep | grep set_dma_latency | awk '{print $NF}')
    test -z "$my_C_STATE_LIMIT" && my_C_STATE_LIMIT="Off"
}


get_C1E_STATE() {
    if [ ! -z "$C1EUTIL" -a -x "$C1EUTIL" ]; then
        my_C1E_STATE=$($C1EUTIL | sed 's/^C1E //')
    fi

    if [ -z $my_C1E_STATE ]; then
        my_C1E_STATE_SUMMARY="Unavailable"
    else
        my_C1E_STATE_SUMMARY=$( c1eutil | awk '{print "Cores " $2}' | sort | uniq -c | sed -r -e 's/^ +//')
    fi
}


set_GOVERNOR() {

    if [ -z "$GOVERNOR" -a ! -z "$GOVERNER" ]; then
        GOVERNOR=$GOVERNER
            # backwards compatible with misspelling in config file
    fi


    if [ -z $GOVERNOR ]; then

        get_SCALING_DRIVER

        if [ "$my_SCALING_DRIVER" = "acpi_cpufreq" ]; then
            GOVERNOR="ondemand"

        elif [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then
            GOVERNOR="performance"
        else
            GOVERNOR="scaling_driver_not_recognized"
                # give a hint at least...
        fi
        
    fi

    grep -qw $GOVERNOR /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
    if [ $? -eq 0 ]; then
        for core in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        do 
            echo -n $GOVERNOR > $core
        done 
    else
        AVAILABLE_GOVERNORS=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors | sed -e "s/^/'/" -e "s/ /', '/g" -e "s/$/'/")
        MSG="ERROR:  Governor '$GOVERNOR' is not supported on this system.  Try one of:  ${AVAILABLE_GOVERNORS}."
        echo $MSG
        test -x $LOGGER && echo $MSG | $LOGGER -t set_cpu_state
    fi
}


set_MIN_FREQ() {
    if [ -z $MIN_FREQ ]; then
        get_MIN_FREQ_AVAILABLE
        MIN_FREQ=$my_MIN_FREQ_AVAILABLE
    fi

    #
    # Make sure the OS doesn't ignore us:
    #
    #   http://askubuntu.com/a/303957/144800
    #
    echo -n 1 > /sys/module/processor/parameters/ignore_ppc

    for core in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq
    do 
        echo -n $MIN_FREQ > $core
    done 
}


set_MAX_FREQ() {
    if [ -z "$MAX_FREQ" ]; then
        get_MAX_FREQ_AVAILABLE
        MAX_FREQ=$my_MAX_FREQ_AVAILABLE
    fi

    #
    # Make sure the OS doesn't ignore us:
    #
    #   http://askubuntu.com/a/303957/144800
    #
    echo -n 1 > /sys/module/processor/parameters/ignore_ppc

    for core in $(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq)
    do 
        echo -n $MAX_FREQ > $core
    done 
}


set_TURBO_ON() {

    get_TURBO_HW_STATE

    if [ "$my_TURBO_HW_STATE" = "On" ]; then

        if [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then
            echo -n 0 > $INTEL_PSTATE_NO_TURBO_file
        fi 

        #
        # Set max freq to the proper freq for turbo use.
        # get_TURBO_HW_STATE will choose the proper freq and set it to
        # $my_TURBO_FREQ.
        #
        #   - With acpi-cpufreq, that's a frequency with '010' in it,
        #     such as 2601000, for example.
        #
        #   - With intel_pstate, it's simply the highest freq for the
        #     proc, such as 2600000, for example.
        # 
        MAX_FREQ=$my_TURBO_FREQ

        set_MAX_FREQ
    fi

}


set_TURBO_OFF() {
    get_SCALING_DRIVER

    if [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then

        set_MAX_FREQ
            # must do this first, for intel_pstate
        get_TURBO_HW_STATE
        if [ "$my_TURBO_HW_STATE" = "On" ]; then
            echo -n 1 > $INTEL_PSTATE_NO_TURBO_file
                # make it go away!!!
        fi

    elif [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        #
        # Set max freq to the proper freq for non-turbo use.
        #
        #   - If not set by the user, set_MAX_FREQ will automatically
        #     choose a proper freq.
        # 
        if [ ! -z $MAX_FREQ ]; then
            MAX_FREQ=$(echo $MAX_FREQ | sed 's/010/000/')
        fi
        set_MAX_FREQ
            # this _is_ how you turn turbo off with acpi-cpufreq
    fi
}


set_C1E_DISABLED() {
    if [ ! -z "$C1EUTIL" -a -x "$C1EUTIL" ]; then
        $C1EUTIL -d >/dev/null 2>&1
    else
        echo "Please install c1eutil.  Can't set c1e state"
    fi
}


set_C1E_ENABLED() {
    if [ ! -z "$C1EUTIL" -a -x "$C1EUTIL" ]; then
        $C1EUTIL -e >/dev/null 2>&1
    else
        echo "Please install c1eutil.  Can't set c1e state"
    fi
}


set_C_STATE_LIMIT() {

    if [ ! -z "$SET_DMA_LATENCY" -a -x "$SET_DMA_LATENCY" ]; then

        killall set_dma_latency >/dev/null 2>&1

        echo "$C_STATE_LIMIT" | egrep -q '^[0-9]+$'
        if [ $? -eq 0 ]; then
            $SET_DMA_LATENCY $C_STATE_LIMIT
        fi
    else
        echo "Please install the set_dma_latency tool.  Can't set C state limit."
    fi
}


set_LIMIT_REAL_CORE_COUNT() {
    #
    # If core count limit is not evenly divisible by number of sockets, we
    # round up so that we have an even number of active cores per socket.
    #
    get_TOTAL_REAL_CORES
    get_TOTAL_HYPERTHREADING_CORES

set -x
    if [ -z "$LIMIT_REAL_CORES" ]; then
        set_ALL_REAL_CORES_on
    
    elif [ "$LIMIT_REAL_CORES" -ge "$cached_CORE_TOTAL_REAL_CORES_COUNT" ]; then
        # make sure all real cores are turned on
        set_ALL_REAL_CORES_on

    elif [ "$LIMIT_REAL_CORES" -lt "$cached_CORE_TOTAL_REAL_CORES_COUNT" ]; then

        local cores_on_per_socket
        local cores_to_turn_on
        local cores_to_turn_off

        cores_on_per_socket=$(awk "BEGIN {print $LIMIT_REAL_CORES / $cached_SOCKETS_COUNT}")
        echo $cores_on_per_socket | grep '\.' 
        if [ $? -eq 0 ]; then
            let cores_on_per_socket+=1
        fi
echo "cores_on_per_socket: $cores_on_per_socket"
        for socket in $cached_SOCKETS_LIST
        do
            for i in $(seq 1 $cores_on_per_socket)
            do

                core=$(echo ${cached_CORES_BY_SOCKET[$socket]} | awk "{print \$$i}")

                cores_to_turn_on="$cores_to_turn_on $core"
            done
        done

        # Because cores start at 0, we can start at the $cores_on_per_socket value
        start=$cores_on_per_socket
        for socket in $cached_SOCKETS_LIST
        do
echo "socket: $socket"
echo "start: $start"
echo "cached_CORE_CORES_PER_SOCKET: $cached_CORE_CORES_PER_SOCKET"
            for i in $(seq $start $cached_CORE_CORES_PER_SOCKET)
            do
                core=$(echo ${cached_CORES_BY_SOCKET[$socket]} | awk "{print \$$i}")

                cores_to_turn_off="$cores_to_turn_off $core"
            done
        done

#XXX FIX ME!
echo cores to turn on: $cores_to_turn_on
echo cores to turn off: $cores_to_turn_off

        for core in $cores_to_turn_on
        do
            # turn on the core
            if [ $core -ne 0 ]; then
                echo "echo -n 1 > /sys/devices/system/cpu/cpu${core}/online"
                echo -n 1 > /sys/devices/system/cpu/cpu${core}/online
            fi

            # and it's sibling (if it has one...), and if HT is on
            if [ ! -z ${cached_THREAD_SIBLINGS_BY_CORE[$core]} -a "$USE_HYPERTHREADING" = "yes" -a ${cached_THREAD_SIBLINGS_BY_CORE[$core]} -ne 0 ]; then
                echo "echo -n 1 > /sys/devices/system/cpu/cpu${cached_THREAD_SIBLINGS_BY_CORE[$core]}/online"
                echo -n 1 > /sys/devices/system/cpu/cpu${cached_THREAD_SIBLINGS_BY_CORE[$core]}/online
            fi
        done

        for core in $cores_to_turn_off
        do
            # turn off the core
            if [ $core -ne 0 ]; then
                echo "echo -n 0 > /sys/devices/system/cpu/cpu${core}/online"
                echo -n 0 > /sys/devices/system/cpu/cpu${core}/online
            fi

            # and it's sibling (if it has one...)
            if [ ! -z ${cached_THREAD_SIBLINGS_BY_CORE[$core]} -a ${cached_THREAD_SIBLINGS_BY_CORE[$core]} -ne 0 ]; then
                echo "echo -n 0 > /sys/devices/system/cpu/cpu${cached_THREAD_SIBLINGS_BY_CORE[$core]}/online"
                echo -n 0 > /sys/devices/system/cpu/cpu${cached_THREAD_SIBLINGS_BY_CORE[$core]}/online
            fi
        done
    fi
set +x
}


set_INITIALIZE_CPU_MAP_CACHE() {

    local DIR=$(dirname $cpu_map_cache_FILE)
    mkdir -p $DIR

    DATESTAMP=$(date +%Y-%m-%d,%H:%M:%S) 
    echo "#"                                        >  $cpu_map_cache_FILE
    echo "# $PROGNAME initialized $DATESTAMP"       >> $cpu_map_cache_FILE
    echo "#"                                        >> $cpu_map_cache_FILE

    #
    # Make sure we can see everything...
    set_ALL_REAL_and_HYPERTHREADING_CORES_on

    #
    # Get state
    #
    get_HYPERTHREADING_STATE
    get_TURBO_HW_STATE

    #
    # Document it
    #
    echo "cached_SOCKETS_COUNT=$my_SOCKETS_COUNT"                                                                   >> $cpu_map_cache_FILE
    echo "cached_SOCKETS_LIST='$my_SOCKETS_LIST'"                                                                   >> $cpu_map_cache_FILE
    echo "cached_TURBO_HW_STATE=$my_TURBO_HW_STATE"                                                                 >> $cpu_map_cache_FILE
    echo "cached_HYPERTHREADING_HW_STATE=$my_HYPERTHREADING_HW_STATE"                                               >> $cpu_map_cache_FILE
    echo "cached_CORE_CORES_PER_SOCKET=$my_CORES_PER_SOCKET"                                                        >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_CORES_COUNT=$my_TOTAL_REAL_CORES_COUNT"                                            >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_HYPERTHREADING_CORES_COUNT=$my_TOTAL_HYPERTHREADING_CORES_COUNT"                        >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT=$my_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT"      >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST='$my_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST'"      >> $cpu_map_cache_FILE

    for socket in $my_SOCKETS_LIST
    do
        echo "cached_CORES_BY_SOCKET[$socket]='${my_CORES_BY_SOCKET[$socket]}'"                                     >> $cpu_map_cache_FILE
    done

    for cpu in $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_LIST
    do
        my_SIBLINGS=$(grep -w $cpu /sys/devices/system/cpu/cpu${cpu}/topology/thread_siblings_list | sed -e "s/${cpu}-//" -e "s/-${cpu}//" )
        echo "cached_THREAD_SIBLINGS_BY_CORE[$cpu]='$my_SIBLINGS'"                                                  >> $cpu_map_cache_FILE
    done

    cached_CORE_TOTAL_REAL_CORES_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u | sed -e 's/-.*/ /' | tr -d '\n')
    cached_CORE_TOTAL_REAL_CORES_LIST=$(echo $cached_CORE_TOTAL_REAL_CORES_LIST | sed -r -e 's/^ +//' -e 's/ +$//')
    echo "cached_CORE_TOTAL_REAL_CORES_LIST='$cached_CORE_TOTAL_REAL_CORES_LIST'"                                   >> $cpu_map_cache_FILE

    cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u | sed -e 's/.*-/ /' | tr -d '\n')
    cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST=$(echo $cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST | sed -r -e 's/^ +//' -e 's/ +$//')
    echo "cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST='$cached_CORE_TOTAL_HYPERTHREADING_CORES_LIST'"               >> $cpu_map_cache_FILE
}


read_CPU_MAP_CACHE() {

    if [ ! -e "$cpu_map_cache_FILE" ]; then
        set_INITIALIZE_CPU_MAP_CACHE
    else
        DATE_OF_LAST_BOOT=$( date +%s --date="$(uptime -s)" )
        DATE_OF_CACHE_UPDATE=$( stat -L --format=%Y "$cpu_map_cache_FILE" )

        if [ $DATE_OF_LAST_BOOT -gt $DATE_OF_CACHE_UPDATE ]; then
            set_INITIALIZE_CPU_MAP_CACHE
        fi
    fi

    . "$cpu_map_cache_FILE"
}

#
#   END functions
#
########################################################################
#   vim:set ts=4 et ai tw=0:
