#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <sys/types.h>
#include <sys/wait.h>


int undaemonize(char *argv[]) {
  int fd[2];
  int count, err, rc;
  pid_t chpid;

  if (pipe(fd)) {
    perror("pipe");
    return EX_OSERR;
  }

  if (prctl(PR_SET_CHILD_SUBREAPER, 1)) {
    perror("prctl");
    return EX_OSERR;
  }

  /* Ensure that the write pipe closes if execvp is successful. */
  if (fcntl(fd[1], F_SETFD, fcntl(fd[1], F_GETFD) | FD_CLOEXEC)) {
    perror("fcntl");
    return EX_OSERR;
  }

  switch (chpid = fork()) {
  case -1:
    perror("fork");
    return EX_OSERR;

  case 0:
    close(fd[0]);

    /* CHILD_SUBREAPER doesn't persist across forks */
    if (prctl(PR_SET_CHILD_SUBREAPER, 1) == -1) {
      write(fd[1], &errno, sizeof(errno));
    }
    execvp(argv[0], argv);
    write(fd[1], &errno, sizeof(errno));
    _exit(0);

  default:
    close(fd[1]);

    while ((count = read(fd[0], &err, sizeof(errno))) == -1) {
      if (errno != EAGAIN && errno != EINTR) {
        break;
      }
    }
    close(fd[0]);

    if (count) {
      fprintf(stderr, "process error: %s\n", strerror(err));
      return EX_UNAVAILABLE;
    }

    /* Wait on all remaining children, storing return code of first process to
     * exit abnormally. */
    rc = 0;
    while (wait(&err) > 0) {
      if (errno && errno != EINTR) {
        perror("wait");
        return EX_SOFTWARE;
      }
      if (WIFEXITED(err) && rc == 0) {
        rc = WEXITSTATUS(err);
      }
    }
    return rc;
  }
}


int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "Usage: undaemonize <PROGRAM> [ARGS...]\n");
    return EX_USAGE;
  }

  return undaemonize(argv + 1);
}
