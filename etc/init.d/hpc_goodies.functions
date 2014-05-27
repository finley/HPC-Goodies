#!/bin/bash
#
# 2014.02.25 Brian Elliott Finley <bfinley@us.ibm.com>
#   - created
#

TAIL=$(which tail)
SEQ=$(which seq)
C1EUTIL=$(which c1eutil)
SET_DMA_LATENCY=$(which set_dma_latency)

get_TURBO_HW_STATE() {
    modprobe acpi_cpufreq
    grep -q 010 /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies 
    if [ $? -eq 0 ]; then
        my_TURBO_HW_STATE=On 
        my_TURBO_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies | awk '{print $1}')
    else
        my_TURBO_HW_STATE=Off
    fi
}

get_TURBO_ENGAGED() {
    get_TURBO_HW_STATE
    if [ "$my_TURBO_HW_STATE" = "On" ]; then
        get_MAX_FREQ_ACTIVE
        my_TURBO_ENGAGED=$(echo "$my_MAX_FREQ_ACTIVE" | grep 010 | awk '{print $1 " cores engaged"}')
        if [ -z "$my_TURBO_ENGAGED" ]; then
            # Nothing there, must not have any engaged -BEF-
            my_TURBO_ENGAGED="No"
        fi
    else
        my_TURBO_ENGAGED="No"
    fi
}

get_GOVERNER_ACTIVE() {
    my_GOVERNER_ACTIVE=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores using /'
        )
}

get_MAX_FREQ_ACTIVE() {
    my_MAX_FREQ_ACTIVE=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores at /'
        )
}

get_MIN_FREQ_ACTIVE() {
    my_MIN_FREQ_ACTIVE=$(
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq \
        | sort | uniq -c \
        | sed -e 's/^ *//' -e 's/ / cores at /'
        )
}

get_MAX_FREQ_AVAILABLE() {
    get_TURBO_HW_STATE
    if [ "$my_TURBO_HW_STATE" = "On" ]; then
        my_MAX_FREQ_AVAILABLE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies | awk '{print $2}')
    else
        my_MAX_FREQ_AVAILABLE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies | awk '{print $1}')
    fi
}

get_MIN_FREQ_AVAILABLE() {
    modprobe acpi_cpufreq
    my_MIN_FREQ_AVAILABLE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies | awk '{print $NF}')
}

get_CPU_ACTIVE_REAL_CORES() {
    my_CPU_ACTIVE_REAL_CORES_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | sed -r -e 's/[^0-9].*//' \
        | sort -u
        )
    # This is the count of active hyperthread cores
    my_CPU_ACTIVE_REAL_CORES_COUNT=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | sed -r -e 's/[^0-9].*//' \
        | sort -u \
        | wc -l
        )
}

get_CPU_ACTIVE_HYPERTHREAD_CORES() {
    # This is the list of active hyperthread cores
    my_CPU_ACTIVE_HYPERTHREAD_CORES_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | egrep '[0-9]+[^0-9]+[0-9]+' \
        | sed -r -e 's/^[0-9]+[^0-9]+//' \
        | sort -u
        )
    # This is the count of active hyperthread cores
    my_CPU_ACTIVE_HYPERTHREAD_CORES_COUNT=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list \
        | egrep '[0-9]+[^0-9]+[0-9]+' \
        | sed -r -e 's/^[0-9]+[^0-9]+//' \
        | sort -u \
        | wc -l
        )
}

get_CPU_SOCKETS() {
    my_CPU_SOCKETS_LIST=$(cat /sys/devices/system/cpu/cpu*/topology/physical_package_id  | sort -u)
    my_CPU_SOCKETS_COUNT=$(echo "$my_CPU_SOCKETS_LIST" | wc -l)
}

get_CPU_TOTAL_REAL_AND_HYPERTHREADING_CORES() {
    my_CPU_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT=$(( $(/bin/ls /sys/devices/system/cpu/cpu*/online | wc -l) + 1 ))
}

get_CPU_TOTAL_HYPERTHREADING_CORES() {

    get_CPU_TOTAL_REAL_AND_HYPERTHREADING_CORES
    get_CPU_TOTAL_REAL_CORES

    my_CPU_TOTAL_HYPERTHREADING_CORES_COUNT=$(( $my_CPU_TOTAL_REAL_AND_HYPERTHREADING_CORES_COUNT - $my_CPU_TOTAL_REAL_CORES_COUNT ))
}

get_CPU_TOTAL_REAL_CORES() {
    get_CPU_SOCKETS
    my_CPU_CORES_PER_SOCKET=$(grep 'cpu cores' /proc/cpuinfo | sort -u | awk '{print $NF}')
    my_CPU_TOTAL_REAL_CORES_COUNT=$(( $my_CPU_SOCKETS_COUNT * $my_CPU_CORES_PER_SOCKET ))
}

get_CPU_OFFLINE() {
	my_CPU_OFFLINE_COUNT=$(grep -w 1 /sys/devices/system/cpu/cpu*/online | wc -l)
	my_CPU_OFFLINE_LIST=$(grep -w 1 /sys/devices/system/cpu/cpu*/online | wc -l)
}

get_HYPERTHREADING_STATE() {
  
	get_CPU_ACTIVE_HYPERTHREAD_CORES
    if [ "$my_CPU_ACTIVE_HYPERTHREAD_CORES_COUNT" -eq "0" ]; then
        my_HYPERTHREADING_OS_STATE=Off
    else
        my_HYPERTHREADING_OS_STATE=On
    fi

    get_CPU_TOTAL_HYPERTHREADING_CORES
    if [ "$my_CPU_TOTAL_HYPERTHREADING_CORES_COUNT" -eq "0" ]; then
        my_HYPERTHREADING_HW_STATE=Off
    else
        my_HYPERTHREADING_HW_STATE=On
    fi
}

set_HYPERTHREADING_ON() {
    
    for core in /sys/devices/system/cpu/cpu*/online
    do
        echo 1 > $core
    done
}

set_HYPERTHREADING_OFF() {

	get_CPU_ACTIVE_HYPERTHREAD_CORES

    for core in $my_CPU_ACTIVE_HYPERTHREAD_CORES_LIST
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

    if [ -z "$my_C1E_STATE" ]; then
        my_C1E_STATE="Unknown"
    else
        my_C1E_STATE_SUMMARY=$( c1eutil | awk '{print "Cores " $2}' | sort | uniq -c | sed -r -e 's/^ +//')
    fi
}

set_GOVERNER() {
    if [ ! -z $GOVERNER ]; then
        for core in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        do 
            echo $GOVERNER > $core
        done 
    fi
}

set_MIN_FREQ() {
    if [ -z $MIN_FREQ ]; then
        get_MIN_FREQ_AVAILABLE
        MIN_FREQ=$my_MIN_FREQ_AVAILABLE
    fi

    for core in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq
    do 
        echo $MIN_FREQ > $core
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
    echo 1 > /sys/module/processor/parameters/ignore_ppc

    for core in $(/bin/ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq)
    do 
        echo $MAX_FREQ > $core
    done 
}

set_TURBO_ON() {

    get_TURBO_HW_STATE

    if [ ! -z "$my_TURBO_FREQ" ]; then
        MAX_FREQ=$my_TURBO_FREQ
        set_MAX_FREQ
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
        echo "Please install set_dma_latency.  Can't set C state limit."
    fi
}

