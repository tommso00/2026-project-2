#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "ipc.h"

int make_device_fifo_path(device_id_t id, char *buffer, size_t buffer_len) {
    if (buffer == NULL || buffer_len == 0) {
        return ERR_INVALID_PARAMETERS;
    }

    snprintf(buffer, buffer_len, "%s/device_%d.fifo", FIFO_DIR, id);
    return OK;
}

int make_reply_fifo_path(pid_t pid, int request_id, char *buffer, size_t buffer_len) {
    if (buffer == NULL || buffer_len == 0) {
        return ERR_INVALID_PARAMETERS;
    }

    snprintf(buffer, buffer_len, "%s/reply_%d_%d.fifo", FIFO_DIR, (int)pid, request_id);
    return OK;
}

int send_message(const char *fifo_path, const message_t *msg) {
    int fd;
    ssize_t written;

    if (fifo_path == NULL || msg == NULL) {
        return ERR_INVALID_PARAMETERS;
    }

    fd = open(fifo_path, O_WRONLY);
    if (fd < 0) {
        return ERR_IPC_FAILURE;
    }

    written = write(fd, msg, sizeof(*msg));
    close(fd);

    if (written != (ssize_t)sizeof(*msg)) {
        return ERR_IPC_FAILURE;
    }

    return OK;
}

int recv_message(int fd, message_t *msg) {
    ssize_t n;

    if (fd < 0 || msg == NULL) {
        return ERR_INVALID_PARAMETERS;
    }

    n = read(fd, msg, sizeof(*msg));
    if (n <= 0) {
        return ERR_IPC_FAILURE;
    }

    if (n != (ssize_t)sizeof(*msg)) {
        return ERR_IPC_FAILURE;
    }

    return OK;
}

int request_reply(const char *request_fifo,
                       const char *reply_fifo,
                       const message_t *request,
                       message_t *response) {
    int fd;
    int rc;

    if (request_fifo == NULL || reply_fifo == NULL || request == NULL || response == NULL) {
        return ERR_INVALID_PARAMETERS;
    }

    unlink(reply_fifo);
    if (mkfifo(reply_fifo, 0666) != 0) {
        return ERR_IPC_FAILURE;
    }

    rc = send_message(request_fifo, request);
    if (rc != OK) {
        unlink(reply_fifo);
        return rc;
    }

    fd = open(reply_fifo, O_RDONLY);
    if (fd < 0) {
        unlink(reply_fifo);
        return ERR_IPC_FAILURE;
    }

    rc = recv_message(fd, response);
    close(fd);
    unlink(reply_fifo);
    return rc;
}