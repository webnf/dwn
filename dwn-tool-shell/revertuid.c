#define _GNU_SOURCE
#include <sched.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <unistd.h>
#include <string.h>

void remap(const char *conf_path, const char *id) {
  int fd;
  fd=open(conf_path, O_WRONLY);
  write(fd,id,strlen(id));
  write(fd," 0 1",4);
  close(fd);
}

int main(int argc, char *argv[]) {
    int fd;

    unshare(CLONE_NEWUSER);
    fd=open("/proc/self/setgroups",O_WRONLY);
    write(fd,"deny",4);
    close(fd);
    remap("/proc/self/uid_map", argv[1]);
    remap("/proc/self/gid_map", argv[2]);
    execvp(argv[3],argv+3);
}
