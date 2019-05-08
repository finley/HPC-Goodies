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
#SCALING_DRIVER_file=$(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver | head -n 1)
INTEL_PSTATE_NO_TURBO_file="/sys/devices/system/cpu/intel_pstate/no_turbo"
CPUINFO_MAX_FREQ_file="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
CPUINFO_MIN_FREQ_file="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"

########################################################################
#
#   BEGIN functions
#
get_SCALING_DRIVER() {

    if [ ! -e "$SCALING_DRIVER_file" ]; then
        # No scaling driver loaded yet, so let's load our preferred driver -BEF-
        modprobe -r acpi_pad
        modprobe acpi_cpufreq 2>/dev/null
    fi

    if [ -e "$SCALING_DRIVER_file" ]; then
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

        if [ -e "$INTEL_PSTATE_NO_TURBO_file" ]; then
            my_TURBO_HW_STATE=On
        else
            my_TURBO_HW_STATE=Off
        fi

        get_MAX_FREQ_AVAILABLE
        my_TURBO_FREQ=$my_MAX_FREQ_AVAILABLE


    elif [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        get_SCALING_AVAILABLE_FREQUENCIES

        echo $my_SCALING_AVAILABLE_FREQUENCIES | grep -q 010
        if [ $? -eq 0 ]; then
            my_TURBO_HW_STATE=On 
            my_TURBO_FREQ=$(echo $my_SCALING_AVAILABLE_FREQUENCIES | awk '{print $1}')
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

    get_SCALING_DRIVER

    if [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        get_CORE_ONLINE

        online_SCALING_GOVERNOR_files=""
        for NUMBER in $my_CORE_ONLINE_list
        do
	        online_SCALING_GOVERNOR_files="$online_SCALING_GOVERNOR_files /sys/devices/system/cpu/cpu$NUMBER/cpufreq/scaling_governor"
        done

        my_SCALING_GOVERNOR=$(
            cat $online_SCALING_GOVERNOR_files \
            | sort | uniq -c \
            | sed -e 's/^ *//' -e 's/ / cores using /'
            )
    else
        my_SCALING_GOVERNOR="UNKNOWN"
    fi
}


get_SCALING_MAX_FREQ_state() {

    get_SCALING_DRIVER

    if [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        get_CORE_ONLINE

        online_SCALING_MAX_FREQ_files=""
        for NUMBER in $my_CORE_ONLINE_list
        do
	        online_SCALING_MAX_FREQ_files="$online_SCALING_MAX_FREQ_files /sys/devices/system/cpu/cpu$NUMBER/cpufreq/scaling_max_freq"
        done

        my_SCALING_MAX_FREQ_state=$(
            cat $online_SCALING_MAX_FREQ_files \
            | sort | uniq -c \
            | sed -e 's/^ *//' -e 's/ / cores at /'
            )
    else
        my_SCALING_MAX_FREQ_state="UNKNOWN"
    fi
}

get_SCALING_MIN_FREQ_state() {

    get_SCALING_DRIVER

    if [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then

        get_CORE_ONLINE

        online_SCALING_MIN_FREQ_state=""
        for NUMBER in $my_CORE_ONLINE_list
        do
	        online_SCALING_MIN_FREQ_state="$online_SCALING_MIN_FREQ_state /sys/devices/system/cpu/cpu$NUMBER/cpufreq/scaling_min_freq"
        done

        my_SCALING_MIN_FREQ_state=$(
            cat $online_SCALING_MIN_FREQ_state \
            | sort | uniq -c \
            | sed -e 's/^ *//' -e 's/ / cores at /'
            )
    else
        my_SCALING_MIN_FREQ_state="UNKNOWN"
    fi
}


get_SCALING_AVAILABLE_FREQUENCIES() {

    my_SCALING_AVAILABLE_FREQUENCIES=$(cat $acpi_cpufreq_SCALING_AVAILABLE_FREQUENCIES_file)
}


get_MAX_FREQ_AVAILABLE() {
    my_MAX_FREQ_AVAILABLE=$(cat $CPUINFO_MAX_FREQ_file)
}


get_MIN_FREQ_AVAILABLE() {
    my_MIN_FREQ_AVAILABLE=$(cat $CPUINFO_MIN_FREQ_file)
}


get_ACTIVE_REAL_AND_HYPERTHREADING_CORES() {
    my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_list=$(
        /bin/ls /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | sed -e 's/.*cpu\/cpu//' -e 's/\/.*/ /' \
        | tr -d '\n' \
        )
}


get_ACTIVE_REAL_CORES() {

    get_ACTIVE_REAL_AND_HYPERTHREADING_CORES

    my_REGEX=$(echo $my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_list | sed -e 's/ /|/g' -e 's/|$//')

    my_ACTIVE_REAL_CORES_list=$(echo  $cached_CORE_TOTAL_REAL_CORES_list | tr ' ' '\n' | egrep    -w "($my_REGEX)")
    my_ACTIVE_REAL_CORES_count=$(echo $cached_CORE_TOTAL_REAL_CORES_list | tr ' ' '\n' | egrep -c -w "($my_REGEX)")
}


get_ACTIVE_HYPERTHREADING_CORES() {

    get_ACTIVE_REAL_AND_HYPERTHREADING_CORES

    my_REGEX=$(echo $my_ACTIVE_REAL_AND_HYPERTHREADING_CORES_list | sed -e 's/ /|/g' -e 's/|$//')
    
    my_ACTIVE_HYPERTHREADING_CORES_list=$(echo  $cached_CORE_TOTAL_HYPERTHREADING_CORES_list | tr ' ' '\n' | egrep    -w "($my_REGEX)")
    my_ACTIVE_HYPERTHREADING_CORES_count=$(echo $cached_CORE_TOTAL_HYPERTHREADING_CORES_list | tr ' ' '\n' | egrep -c -w "($my_REGEX)")
}


get_SOCKETS() {
    my_SOCKETS_list=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id  | sort -u)
    my_SOCKETS_count=$(echo "$my_SOCKETS_list" | grep . | wc -l)
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l

    for socket in $my_SOCKETS_list
    do
        my_CORES_BY_SOCKET[$socket]=$(grep -l $socket /sys/devices/system/cpu/cpu*/topology/physical_package_id | sed -e 's/.*cpu\/cpu//' -e 's/\/.*/ /' | tr -d '\n')

        # trim space off the end
        my_CORES_BY_SOCKET[$socket]=$(echo ${my_CORES_BY_SOCKET[$socket]} | sed -r -e 's/^ +//' -e 's/ +$//')
    done

}


get_TOTAL_REAL_AND_HYPERTHREADING_CORES() {
    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_count=$(/bin/ls /sys/devices/system/cpu/cpu*/online | grep . | wc -l)
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l

    #
    # And apparently not all kernels present an 'online' file for cpu0.  For
    # example, 3.10.x does, but 4.4.x does not. -BEF-
    #
    if [ ! -e /sys/devices/system/cpu/cpu0/online ]; then
        let my_TOTAL_REAL_AND_HYPERTHREADING_CORES_count++
    fi
    
    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list=$(/bin/ls /sys/devices/system/cpu/cpu*/online | awk -F'/' '{print $6}' | sed -e 's/cpu//')
    if [ ! -e /sys/devices/system/cpu/cpu0/online ]; then
	    my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list="0 $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list"
    fi
}


get_TOTAL_HYPERTHREADING_CORES() {

    get_TOTAL_REAL_AND_HYPERTHREADING_CORES
    get_TOTAL_REAL_CORES

    my_TOTAL_HYPERTHREADING_CORES_count=$(( $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_count - $my_TOTAL_REAL_CORES_count ))
}


get_TOTAL_REAL_CORES() {
    get_SOCKETS
    my_CORES_PER_SOCKET=$(grep 'cpu cores' /proc/cpuinfo | head -n 1 | awk '{print $NF}')
    my_TOTAL_REAL_CORES_count=$(( $my_SOCKETS_count * $my_CORES_PER_SOCKET ))
}


get_CORE_OFFLINE() {
	my_CORE_OFFLINE_count=$(grep -w 0 /sys/devices/system/cpu/cpu*/online | grep . | wc -l)
        # the 'grep .' bit eliminates blank lines, that would be counted by wc -l
	my_CORE_OFFLINE_list=$(grep -w 0 /sys/devices/system/cpu/cpu*/online)
}


get_CORE_ONLINE() {

	my_CORE_ONLINE_list=$(grep -w 1 /sys/devices/system/cpu/cpu*/online | awk -F'/' '{print $6}' | sed -e 's/cpu//')
    echo $my_CORE_ONLINE_list | grep -qw 0 || my_CORE_ONLINE_list="0 $my_CORE_ONLINE_list"

	my_CORE_ONLINE_count=$(echo $my_CORE_ONLINE_list | wc -w)
}


get_HYPERTHREADING_STATE() {
  
	get_ACTIVE_HYPERTHREADING_CORES
    if [ "$my_ACTIVE_HYPERTHREADING_CORES_count" -eq "0" ]; then
        my_HYPERTHREADING_OS_STATE=Off
    else
        my_HYPERTHREADING_OS_STATE=On
    fi

    get_TOTAL_HYPERTHREADING_CORES
    if [ "$my_TOTAL_HYPERTHREADING_CORES_count" -eq "0" ]; then
        my_HYPERTHREADING_HW_STATE=Off
    else
        my_HYPERTHREADING_HW_STATE=On
    fi
}


set_HYPERTHREADING_ON() {

    test ! -z $DEBUG && echo 'set_HYPERTHREADING_ON()'

    if [ "$cached_HYPERTHREADING_HW_STATE" = "On" ]; then

        get_ACTIVE_REAL_CORES

        for core in $my_ACTIVE_REAL_CORES_list
        do
            sibling=${cached_THREAD_SIBLINGS_BY_CORE[$core]}
            if [ "$sibling" -ne 0 ]; then
                echo -n 1 > /sys/devices/system/cpu/cpu${sibling}/online
            fi
            
        done
    fi
}


set_ALL_REAL_and_HYPERTHREADING_CORES_on() {
    
    for core in /sys/devices/system/cpu/cpu*/online
    do
        echo -n 1 > $core
    done
}


set_ALL_HYPERTHREADING_CORES_on() {
    
    for core in $cached_CORE_TOTAL_HYPERTHREADING_CORES_list
    do
        if [ "$core" -ne 0 ]; then
            echo -n 1 > /sys/devices/system/cpu/cpu${core}/online
        fi
    done
}


set_ALL_REAL_CORES_on() {
    
    for core in $cached_CORE_TOTAL_REAL_CORES_list
    do
        if [ "$core" -ne 0 ]; then
            echo -n 1 > /sys/devices/system/cpu/cpu${core}/online
        fi
    done
}



set_HYPERTHREADING_OFF() {

    test ! -z $DEBUG && echo 'set_HYPERTHREADING_OFF()'

	get_ACTIVE_HYPERTHREADING_CORES

    for core in $my_ACTIVE_HYPERTHREADING_CORES_list
    do
        # turn it off
        echo -n 0 > /sys/devices/system/cpu/cpu${core}/online
    done
}


set_HYPERTHREADING_STATE() {

    test ! -z $DEBUG && echo 'set_HYPERTHREADING_STATE()'

    if [ $USE_HYPERTHREADING -eq 1 ]; then
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

    if [ -z "$my_C1E_STATE" ]; then
        my_C1E_STATE_SUMMARY="Unavailable"
    else
        my_C1E_STATE_SUMMARY=$( c1eutil | awk '{print "Cores " $2}' | sort | uniq -c | sed -r -e 's/^ +//')
    fi
}


set_GOVERNOR() {

    test ! -z $DEBUG && echo 'set_GOVERNOR()'

    if [ -z "$GOVERNOR" -a ! -z "$GOVERNER" ]; then
        GOVERNOR=$GOVERNER
            # backwards compatible with misspelling in config file
    fi


    if [ -z "$GOVERNOR" ]; then

        get_SCALING_DRIVER

        if [ "$my_SCALING_DRIVER" = "acpi-cpufreq" ]; then
            GOVERNOR="performance"

        elif [ "$my_SCALING_DRIVER" = "intel_pstate" ]; then
            GOVERNOR="performance"
        else
            GOVERNOR="scaling_driver_not_recognized"
                # give a hint at least...
        fi
        
    fi

    SCALING_AVAILABLE_GOVERNORS_file=$(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors | head -n 1)
    grep -qw $GOVERNOR $SCALING_AVAILABLE_GOVERNORS_file
    if [ $? -eq 0 ]; then

        for cpu in $(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | awk -F'/' '{print $6}')
        do 

            ONLINE_file=/sys/devices/system/cpu/$cpu/online
            SCALING_GOVERNOR_file=/sys/devices/system/cpu/$cpu/cpufreq/scaling_governor

            if [ "$cpu" = "cpu0" ]; then

                echo -n $GOVERNOR > $SCALING_GOVERNOR_file

            elif [ -e $ONLINE_file ]; then

                grep -qw 1 $ONLINE_file && echo -n $GOVERNOR > $SCALING_GOVERNOR_file

            fi
        done 

    else

        AVAILABLE_GOVERNORS=$(cat $SCALING_AVAILABLE_GOVERNORS_file | sed -e "s/^/'/" -e "s/ /', '/g" -e "s/$/'/")
        MSG="ERROR:  Governor '$GOVERNOR' is not supported on this system.  Try one of:  ${AVAILABLE_GOVERNORS}."
        echo $MSG
        test -x $LOGGER && echo $MSG | $LOGGER -t set-cpu-state
    fi
}


set_MIN_FREQ() {

    if [ -z "$MIN_FREQ" ]; then
        get_MIN_FREQ_AVAILABLE
        MIN_FREQ=$my_MIN_FREQ_AVAILABLE
    fi

    #
    # Make sure the OS doesn't ignore us:
    #
    #   http://askubuntu.com/a/303957/144800
    #
    IGNORE_PPC_file=/sys/module/processor/parameters/ignore_ppc
    if [ -e $IGNORE_PPC_file ]; then
        grep -qw 1 $IGNORE_PPC_file || echo -n 1 > $IGNORE_PPC_file
    fi

    for cpu in $(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq | awk -F'/' '{print $6}')
    do 

        ONLINE_file=/sys/devices/system/cpu/$cpu/online
        SCALING_MIN_FREQ_file=/sys/devices/system/cpu/$cpu/cpufreq/scaling_min_freq

        if [ "$cpu" = "cpu0" ]; then

            echo -n $MIN_FREQ > $SCALING_MIN_FREQ_file

        elif [ -e $ONLINE_file ]; then

            grep -qw 1 $ONLINE_file && echo -n $MIN_FREQ > $SCALING_MIN_FREQ_file

        fi
    done 
}


set_MAX_FREQ() {

    local my_FREQ

    if [ ! -z $1 ]; then

        my_FREQ=$1

    elif [ -z "$MAX_FREQ" ]; then

        get_MAX_FREQ_AVAILABLE
        my_FREQ=$my_MAX_FREQ_AVAILABLE
    fi

    #
    # Make sure the OS doesn't ignore us:
    #
    #   http://askubuntu.com/a/303957/144800
    #
    IGNORE_PPC_file=/sys/module/processor/parameters/ignore_ppc
    if [ -e $IGNORE_PPC_file ]; then
        grep -qw 1 $IGNORE_PPC_file || echo -n 1 > $IGNORE_PPC_file
    fi

    for cpu in $(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq | awk -F'/' '{print $6}')
    do 

        ONLINE_file=/sys/devices/system/cpu/$cpu/online
        SCALING_MAX_FREQ_file=/sys/devices/system/cpu/$cpu/cpufreq/scaling_max_freq

        if [ "$cpu" = "cpu0" ]; then

            echo -n $my_FREQ > $SCALING_MAX_FREQ_file

        elif [ -e $ONLINE_file ]; then

            grep -qw 1 $ONLINE_file && echo -n $my_FREQ > $SCALING_MAX_FREQ_file

        fi
    done 
}


set_TURBO_ON() {

    test ! -z "$DEBUG" && echo "set_TURBO_ON()"

    if [ ! -z "$MAX_FREQ" ]; then

        set_MAX_FREQ $MAX_FREQ
            # Any MAX_FREQ setting overrides a USE_TURBO setting

    else

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
            set_MAX_FREQ $my_TURBO_FREQ
        fi
    fi

}


set_TURBO_OFF() {

    test ! -z "$DEBUG" && echo "set_TURBO_OFF()"

    if [ ! -z "$MAX_FREQ" ]; then

        set_MAX_FREQ $MAX_FREQ
            # Any MAX_FREQ setting overrides a USE_TURBO setting

    else

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

            get_MAX_FREQ_AVAILABLE

            #
            # Set max freq to the proper freq for non-turbo use.
            #
            my_FREQ=$(echo $my_MAX_FREQ_AVAILABLE | sed -e 's/010/000/')

            set_MAX_FREQ $my_FREQ
        fi
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

        kill $(pidof set_dma_latency) >/dev/null 2>&1

        echo "$C_STATE_LIMIT" | egrep -q '^[0-9]+$'
        if [ $? -eq 0 ]; then
            $SET_DMA_LATENCY $C_STATE_LIMIT
        fi
    else
        echo "Please install the set_dma_latency tool.  Can't set C state limit."
    fi
}


set_LIMIT_REAL_CORE_count() {

    test ! -z $DEBUG && echo 'set_LIMIT_REAL_CORE_count()'

    local desired_real_cores_per_socket_count

    get_TOTAL_REAL_CORES
    get_TOTAL_HYPERTHREADING_CORES

    test ! -z $DEBUG && echo LIMIT_REAL_CORES_TO_COUNT $LIMIT_REAL_CORES_TO_COUNT
    if [ -z "$LIMIT_REAL_CORES_TO_COUNT" ]; then
        LIMIT_REAL_CORES_TO_COUNT=$cached_CORE_TOTAL_REAL_CORES_count
    fi
    
    if [ "$LIMIT_REAL_CORES_TO_COUNT" -ge "$cached_CORE_TOTAL_REAL_CORES_count" ]; then
        for core in $(seq 0 $cached_CORE_HIGHEST_CORE_NUMBER)
        do
            if [ "${cached_CORETYPE_BY_CORE[$core]}" = "real" ]; then
                core_destiny[$core]="on"
            fi
        done

    elif [ "$LIMIT_REAL_CORES_TO_COUNT" -lt "$cached_CORE_TOTAL_REAL_CORES_count" ]; then

        #
        # If core count limit is not evenly divisible by number of sockets, we
        # round up so that we have an even number of active cores per socket.
        #
        desired_real_cores_per_socket_count=$(awk "BEGIN {print $LIMIT_REAL_CORES_TO_COUNT / $cached_SOCKETS_count}" | sed 's/\..*//')
        if [ "$desired_real_cores_per_socket_count" -eq 0 ]; then
            desired_real_cores_per_socket_count=1
        fi
        test ! -z $DEBUG && echo "desired_real_cores_per_socket_count: $desired_real_cores_per_socket_count"

        #
        # Set destiny for all real cores as on or off
        #
        for socket in $cached_SOCKETS_list
        do
            test ! -z $DEBUG && echo "socket $socket"

            local count=0
            for core in $(seq 0 $cached_CORE_HIGHEST_CORE_NUMBER)
            do
                if [ "${cached_SOCKET_BY_CORE[$core]}" -eq "$socket" ]; then
                    
                    if [ "${cached_CORETYPE_BY_CORE[$core]}" = "real" ]; then

                        if [ "$count" -lt "$desired_real_cores_per_socket_count" ]; then
                            core_destiny[$core]="on"
                            let count+=1
                            test ! -z $DEBUG && echo "Core $core is real, and makes for $count of $desired_real_cores_per_socket_count cores desired on socket $socket, so it will be turned on."
                        else
                            core_destiny[$core]="off"
                            test ! -z $DEBUG && echo "Core $core is real, but we already have $count of $desired_real_cores_per_socket_count cores desired on socket $socket, so it will be turned off."
                        fi
                    fi
                fi

                # increment count
                let core+=1
            done
        done
    fi

    #
    # Now set destiny for all hyper cores, based on HT on and real core sibling setting
    #
    for core in $(seq 0 $cached_CORE_HIGHEST_CORE_NUMBER)
    do
        if [ "${cached_CORETYPE_BY_CORE[$core]}" = "hyperthreading" ]; then

            if [ $USE_HYPERTHREADING -eq 1 ]; then

                # is this core's thread sibling's destiny set to on?
                this_hypercores_sibling=${cached_THREAD_SIBLINGS_BY_CORE[$core]}
                if [ "${core_destiny[$this_hypercores_sibling]}" = "on" ]; then
                    core_destiny[$core]="on"
                    test ! -z $DEBUG && echo "Core $core is hyperthreaded, sibling to real core $this_hypercores_sibling, and will be turned on as it's sibling will also be on."
                else
                    core_destiny[$core]="off"
                    test ! -z $DEBUG && echo "Core $core is hyperthreaded, sibling to real core $this_hypercores_sibling, and will be turned off as it's sibling will also be off."
                fi
            else
                # HT is off altogether, just set destiny to off
                core_destiny[$core]="off"
                test ! -z $DEBUG && echo "Core $core is hyperthreaded and will be turned off. (USE_HYPERTHREADING=$USE_HYPERTHREADING_orig)"
            fi
        fi
    done

    #
    # Now we send the core to it's destiny -BEF-
    #
    #   (get it -- core_file.  Ha! ;-)
    local core_file
    for core in $(seq 0 $cached_CORE_HIGHEST_CORE_NUMBER)
    do
        test ! -z $DEBUG && echo "Turning ${cached_CORETYPE_BY_CORE[$core]} core $core ${core_destiny[$core]}."
        core_file="/sys/devices/system/cpu/cpu${core}/online"
        if [ -e "$core_file" -a "${core_destiny[$core]}" = "on" ]; then

            echo -n 1 > "$core_file"

        elif [ -e "$core_file" ]; then

            echo -n 0 > "$core_file"
        fi
    done
}


set_INITIALIZE_CPU_MAP_CACHE() {

    test ! -z $DEBUG && echo 'set_INITIALIZE_CPU_MAP_CACHE()'

    get_SCALING_DRIVER

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
    echo "cached_SOCKETS_count=$my_SOCKETS_count"                                                                   >> $cpu_map_cache_FILE
    echo "cached_SOCKETS_list='$my_SOCKETS_list'"                                                                   >> $cpu_map_cache_FILE
    echo "cached_TURBO_HW_STATE=$my_TURBO_HW_STATE"                                                                 >> $cpu_map_cache_FILE
    echo "cached_HYPERTHREADING_HW_STATE=$my_HYPERTHREADING_HW_STATE"                                               >> $cpu_map_cache_FILE
    echo "cached_CORE_CORES_PER_SOCKET_count=$my_CORES_PER_SOCKET"                                                  >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_CORES_count=$my_TOTAL_REAL_CORES_count"                                            >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_HYPERTHREADING_CORES_count=$my_TOTAL_HYPERTHREADING_CORES_count"                        >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_AND_HYPERTHREADING_CORES_count=$my_TOTAL_REAL_AND_HYPERTHREADING_CORES_count"      >> $cpu_map_cache_FILE
    echo "cached_CORE_TOTAL_REAL_AND_HYPERTHREADING_CORES_list='$my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list'"      >> $cpu_map_cache_FILE

    my_CORE_HIGHEST_CORE_NUMBER=$(echo $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list | tr ' ' '\n' | sort -n | tail -1)
    echo "cached_CORE_HIGHEST_CORE_NUMBER=$my_CORE_HIGHEST_CORE_NUMBER"                                             >> $cpu_map_cache_FILE

    for core in $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list
    do
        # cache socket by core
        socket=$(cat /sys/devices/system/cpu/cpu${core}/topology/physical_package_id)
        echo "cached_SOCKET_BY_CORE[${core}]=$socket"                                                               >> $cpu_map_cache_FILE

        if [ "$my_HYPERTHREADING_HW_STATE" = "Off" ]; then

            coretype="real"

        else

            #
            # cache coretype by core
            #
            #   Apparently some kernels separate real cores from their siblings
            #   with commas, and some with hyphens...  Hence the [-,] below. -BEF-
            #
            realcore=$(  cat /sys/devices/system/cpu/cpu${core}/topology/thread_siblings_list | sed -e 's/[-,].*//')
            hypercore=$( cat /sys/devices/system/cpu/cpu${core}/topology/thread_siblings_list | sed -e 's/.*[-,]//')

            if [ ! -z "$hypercore" -a "$hypercore" -eq "$core" ]; then
                coretype="hyperthreading"

            elif [ ! -z "$realcore" -a "$realcore" -eq "$core" ]; then
                coretype="real"
            fi
        fi

        echo "cached_CORETYPE_BY_CORE[${core}]=$coretype"                                                           >> $cpu_map_cache_FILE

    done


    if [ "$my_HYPERTHREADING_HW_STATE" = "Off" ]; then

        cached_CORE_TOTAL_REAL_CORES_list=$(cat /sys/devices/system/cpu/cpu*/topology/core_id | tr '\n' ' ')
        echo "cached_CORE_TOTAL_REAL_CORES_list='$cached_CORE_TOTAL_REAL_CORES_list'"                                   >> $cpu_map_cache_FILE

    else

        cached_CORE_TOTAL_REAL_CORES_list=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u | sed -e 's/[-,].*/ /' | tr -d '\n')
        cached_CORE_TOTAL_REAL_CORES_list=$(echo $cached_CORE_TOTAL_REAL_CORES_list | sed -r -e 's/^ +//' -e 's/ +$//')
        echo "cached_CORE_TOTAL_REAL_CORES_list='$cached_CORE_TOTAL_REAL_CORES_list'"                                   >> $cpu_map_cache_FILE

        cached_CORE_TOTAL_HYPERTHREADING_CORES_list=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u | sed -e 's/.*[-,]/ /' | tr -d '\n')
        cached_CORE_TOTAL_HYPERTHREADING_CORES_list=$(echo $cached_CORE_TOTAL_HYPERTHREADING_CORES_list | sed -r -e 's/^ +//' -e 's/ +$//')
        echo "cached_CORE_TOTAL_HYPERTHREADING_CORES_list='$cached_CORE_TOTAL_HYPERTHREADING_CORES_list'"               >> $cpu_map_cache_FILE

        for cpu in $my_TOTAL_REAL_AND_HYPERTHREADING_CORES_list
        do
            my_SIBLINGS=$(grep -w $cpu /sys/devices/system/cpu/cpu${cpu}/topology/thread_siblings_list | sed -e "s/${cpu}[-,]//" -e "s/[-,]${cpu}//" )
            echo "cached_THREAD_SIBLINGS_BY_CORE[$cpu]='$my_SIBLINGS'"                                                  >> $cpu_map_cache_FILE
        done
    fi
}


read_CPU_MAP_CACHE() {

    if [ ! -e "$cpu_map_cache_FILE" ]; then
        set_INITIALIZE_CPU_MAP_CACHE
    else
        DATE_OF_LAST_BOOT=$( awk -F. '{print $1}' /proc/uptime )
        DATE_OF_CACHE_UPDATE=$( stat -L --format=%Y "$cpu_map_cache_FILE" )

        if [ "$DATE_OF_LAST_BOOT" -gt "$DATE_OF_CACHE_UPDATE" ]; then
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
