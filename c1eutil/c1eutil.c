#include <stdio.h>
#include <dirent.h>

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
    while ((o = getopt ( argc, argv, "ed")) != -1) {
        switch (o) {
            case 'e':
                enable = 1;
                break;
            case 'd':
                disable = 1;
                break;
        }
    }
        
    cpus = opendir("/dev/cpu");
    if (cpus) {
        while ((cpu = readdir(cpus)) != NULL) {
            snprintf(filename, 128, "/dev/cpu/%s/msr", cpu->d_name);
            msr = fopen(filename, "r+");
            if (!msr) { continue; }
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
}
