/*
    c1eutil -- Get or set the C1E state on CPU cores.

    - Originally created by Jarrod Johnson.
    - Modified/maintained by Brian Finley <bfinley@lenovo.com>.

    2020.03.30 Brian Finley
    - Added help output
    - Added output for systems that do not support C1E state manipulation

*/

#include <stdio.h>
#include <dirent.h>
#include <getopt.h>
#include <stdlib.h>
#include <ctype.h>

int main(int argc, char** argv) {
    DIR *cpus;
    FILE* msr;
    char filename[128];
    struct dirent *cpu;
    char reg[8];
    int o;
    int enable = 0;
    int disable = 0;
    int enabled = 0;
    int help = 0;
    while ((o = getopt ( argc, argv, "hed")) != -1) {
        switch (o) {
            case 'e':
                enable = 1;
                break;
            case 'd':
                disable = 1;
                break;
            case 'h':
                help = 1;
                break;
        }
    }
        
    if (help) {
        printf("Usage: %s [-h|-d|-e]\n", argv[0]);
        printf("  -h  Help -- this output\n");
        printf("  -d  Disable C1E.  This is probably the option you want\n");
        printf("  -e  Enable C1E\n");
        printf("\n");
        printf("  If run with no options, it will show the current C1E state.\n");
        printf("\n");
        return(0);
    }

    cpus = opendir("/dev/cpu");
    if (cpus) {
        while ((cpu = readdir(cpus)) != NULL) {

            /* make sure we're only trying to read CPU data, not any other cruft. -BEF- */
            if ( !isdigit(cpu->d_name[0]) ) {
                continue;
            }

            int ret = snprintf(filename, 128, "/dev/cpu/%s/msr", cpu->d_name);
            if (ret < 0) {
                abort();
            }

            msr = fopen(filename, "r+");
            if (!msr) { 
                printf("C1E can't be controlled on CPU %s\n", cpu->d_name);
                continue; 
            }
            fseek(msr, 0x1fc, SEEK_SET);
            fread(reg, 8, 1, msr);
            if (reg[0] & 0x02) {
                enabled = 1;
            } else {
                enabled = 0;
            }
            if (enable) {
                if (!enabled) {
                    reg[0] |= 0x02;
                    fseek(msr, 0x1fc, SEEK_SET);
                    fwrite(reg, 8, 1, msr);
                }
            } else if (disable) {
                if (enabled) {
                    reg[0] = reg[0] & ~0x02;
                    fseek(msr, 0x1fc, SEEK_SET);
                    fwrite(reg, 8, 1, msr);
                }
            }
            fclose(msr);
            msr = fopen(filename, "r+");
            fseek(msr, 0x1fc, SEEK_SET);
            fread(reg, 8, 1, msr);
            if (reg[0] & 0x02) {
                printf("C1E Enabled on CPU %s\n", cpu->d_name);
            } else {
                printf("C1E Disabled on CPU %s\n", cpu->d_name);
            }
        }
        closedir(cpus);
    }
    /* Consider adding code to tell user if they need to change BIOS
     * setting to allow this support.  Or if their machine can't support
     * it, then why.  -BEF-
     */
}
