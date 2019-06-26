#define _GNU_SOURCE
#include <sched.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <unistd.h>

int main(int argc, char *argv[]) {
    int fd;

    unshare(CLONE_NEWUSER);
    fd=open("/proc/self/setgroups",O_WRONLY);
    write(fd,"deny",4);
    close(fd);
    fd=open("/proc/self/uid_map",O_WRONLY);
    write(fd,"1000 0 1",8);
    close(fd);
    fd=open("/proc/self/gid_map",O_WRONLY);
    write(fd,"1000 0 1",8);
    close(fd);
    execvp(argv[1],argv+1);
}
