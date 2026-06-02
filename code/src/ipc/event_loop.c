#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/select.h>
#include <unistd.h>

#include "common.h"
#include "controller.h"
#include "error_codes.h"
#include "ipc.h"
#include "repl.h"

static int handle_stdin_event(controller *ctrl) {
    if (ctrl == NULL) {
        return ERR_INVALID_PARAMETERS;
    }

    return repl_read_and_execute(ctrl);
}

static int handle_controller_fifo_event(controller *ctrl, int fifo_fd) {
    domo_message msg;
    int rc;

    if (ctrl == NULL || fifo_fd < 0) {
        return ERR_INVALID_PARAMETERS;
    }

    memset(&msg, 0, sizeof(msg));

    rc = ipc_recv_message(fifo_fd, &msg);
    if (rc != OK) {
        return rc;
    }

    ipc_print_message(&msg);
    return OK;
}

int event_loop_run(controller *ctrl) {
    int fifo_fd;
    int keepalive_fd;
    int max_fd;
    int rc;
    int prompt_visible;

    if (ctrl == NULL) {
        return ERR_INVALID_PARAMETERS;
    }

    fifo_fd = ipc_open_fifo_read(CONTROLLER_ID, &keepalive_fd);
    if (fifo_fd < 0) {
        return ERR_IPC_FAILURE;
    }

    prompt_visible = 0;

    while (ctrl->running) {
        fd_set readfds;

        FD_ZERO(&readfds);
        FD_SET(STDIN_FILENO, &readfds);
        FD_SET(fifo_fd, &readfds);

        max_fd = (STDIN_FILENO > fifo_fd) ? STDIN_FILENO : fifo_fd;

        if (!prompt_visible) {
            repl_print_prompt();
            prompt_visible = 1;
        }

        rc = select(max_fd + 1, &readfds, NULL, NULL, NULL);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            close(fifo_fd);
            close(keepalive_fd);
            return ERR_SYSTEM;
        }

        if (FD_ISSET(STDIN_FILENO, &readfds)) {
            rc = handle_stdin_event(ctrl);
            prompt_visible = 0;

            if (!ctrl->running) {
                break;
            }

            if (rc != OK) {
                fprintf(stderr, "Input error: %s\n", error_str(rc));
            }
        }

        if (ctrl->running && FD_ISSET(fifo_fd, &readfds)) {
            rc = handle_controller_fifo_event(ctrl, fifo_fd);
            prompt_visible = 0;

            if (rc != OK) {
                fprintf(stderr, "IPC error: %s\n", error_str(rc));
            }
        }
    }

    close(fifo_fd);
    close(keepalive_fd);
    return OK;
}