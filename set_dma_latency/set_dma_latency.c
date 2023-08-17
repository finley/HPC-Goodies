/*
 * Lenovo(c) 2012
 * (c) Lenovo
 * Jarrod Johnson <jjohnson2@lenovo.com>
 * 2016.09.04 Brian Finley <bfinley@lenovo.com>
 * - Add #include <unistd.h> header to avoide "implicit definition"
 *   errors during compile
 * - Switch from 'killall' to using 'pidof' for syscall to kill self
 *
 *
 * DESCRIPTION:
 *
 * This program simply requests the specified latency limit of the linux
 * kernel  PM QoS interface for DMA.  The only mechanism manipulated, to
 * my knowledge, is the idle states of the processor.  States
 * advertising a lower latency than requested are allowed States
 * advertising a higher latency than requested are forbidden.  I haven't
 * bothered to check what happens if the latency is equal to requested.
 * If you want to map this explicitly to idle states in your
 * implementation, use the sysfs cpuidle entries to see the available
 * states and latencies.
 *
 * For example, on a Sandy Bridge server:
 *
 *  # cd /sys/devices/system/cpu/cpu0/cpuidle/ 
 *  # for state in state*; do tr '\n' ':' < $state/name; cat $state/latency; done
 *  C0:0
 *  SNB-C1:1
 *  SNB-C3:80
 *  SNB-C6:104
 *  SNB-C7:109
 *
 * In this case 'set_dma_latency 0' would forbid all idle states (not
 * recommended, *particularly* if hyperthreaded, as idle HT instances
 * take performance away from HT instances doing meaningful work) '2'
 * would allow C1 (note, also allows C1E if available, which if P states
 * are restricted from going to lowest speed will incur a high penalty
 * transitioning in and out, C1E can only be independently adjusted in
 * firmware configuration).
 * 81 would allow C3, etc etc
 * 
 * My personal guidance is either: Low energy, relatively low latency
 * between deeper C states and operational state, best Turbo boost to
 * single thread performance:
 * 
 * - set_dma_latency unlimited
 * - scaling_min_speed all the way down
 * - scaling_governor set to ondemand
 * 
 * Inefficient energy use, avoid deep C state latency, nearly zero
 * potential for turbo boost to a single thread
 * 
 * - set_dma_latency 2
 * - scaling_min_speed set to nameplate frequency
 * - scaling_max_speed set to either the turbo p state or advertised
 *   frequency (latter for most predictive, consistent results)
 *
 *   Brian's comment update on scaling_max_speed: if scaling_min_speed is set
 *   to nameplate frequency (max), then scaling_max_speed should _not_ be set
 *   to turbo.  This would cause the CPU (already running all cores at max
 *   fequency, and therefore max power, consuming all of TDP) to try and jump
 *   cores up to an even higher power state (not possible) resulting in poor
 *   performance as the socket backs off to protect itself.  set-cpu-state
 *   prevents this scenario, when this tool is invoked as part of
 *   set-cpu-state.
 *
 * - scaling_governor set to ondemand
 * 
 * Catastrophe strikes if one is managed and not the other (if P states
 * forced a certain way without C states being restricted, performance
 * tanks, if converse done, it would be wasteful)
 * 
 * I defer to more in depth performance analysis to performance teams to
 * actually quantify the relative merits of each major strategy from
 * application to application.
 * 
 * At least nsdperf and mmfsd seem to be content with either strategy.
 * gpfs read performance took about a 75%-90% hit if C1E is in effect and P
 * states pinned to maximum rated frequency.  The direct effect can be seen
 * by either examining the 'usage' counters in sysfs for cpuidle entries or
 * a utility like turbostat.
 * 
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/prctl.h>
#include <signal.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
    int fh;
    int validarg;
    int32_t maxlat;
    if (argc != 2) {
        printf ("Usage: %s <max latency in ns>\n",argv[0]);
        exit(1);
    }
    signal(SIGTERM,SIG_IGN);
    system("kill $(pidof set_dma_latency)");
    signal(SIGTERM,SIG_DFL);
    validarg=sscanf(argv[1],"%d",&maxlat);
    if (!validarg) {
        exit(0);
    }
    chdir("/");
    fh=fork();
    if (fh<0) { exit(1); }
    if (fh>0) { exit(0); }
    setsid();
    for (fh=getdtablesize();fh>=0;--fh) close(fh); /* close all descriptors */



    fh=open("/dev/cpu_dma_latency",O_RDWR);
    write(fh,&maxlat,sizeof(int32_t));

    while (1) { sleep(2147483648); }
}
