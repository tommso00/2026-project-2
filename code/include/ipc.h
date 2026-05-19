#ifndef IPC_H
#define IPC_H

#include <stdbool.h>
#include "protocol.h"

//message structure

typedef struct {
    char sender_id[16];         //String: can be a numeric ID (e.g., "0") or "EXT"
    char command[32];           //e.g., "SWITCH, "LINK, "INFO"
    int target_id;              //logical target device ID
    char payload[MAX_MSG_LEN];  // command-specific data (e.g., "power on")
}domo_message;

// IPC and FIFO function prototypes

int ipc_open_fifo_read (int my_id, int *keepalive_fd);
int ipc_recv_message(int fd_in, domo_message *msg);
int ipc_send_message (const domo_message *msg);

#endif