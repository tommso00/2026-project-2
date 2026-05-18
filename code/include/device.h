#ifndef DEVICE_H
#define DEVICE_H

#include "common.h"
#include "ipc.h"

typedef enum {
    DEVICE_CONTROLLER = 0,
    DEVICE_HUB,
    DEVICE_TIMER,
    DEVICE_BULB,
    DEVICE_WINDOW,
    DEVICE_FRIDGE
} device_type ;

typedef struct {
    device_id id;
    device_type type;
    pid_t pid;
    device_id logical_parent_id;
    state state;
    bool manual_override;
    char fifo_path[PATH_MAX];
    char name[NAME_MAX];
} device_info ;

typedef struct device device ;

typedef int (*device_init)(device *dev);
typedef int (*device_handle)(device *dev,const message *req, message *resp);
typedef int (*device_destroy)(device *dev);

struct device {
    device_info info;

    int child_count;
    device_id child_ids[32];

    char registry_snapshot[PAYLOAD_MAX];

    device_init init ;
    device_handle handle_message;
    device_destroy destroy;

    void *impl;
};

const char *device_type_str(device_type type);
bool device_is_control(device_type type);
bool device_is_interaction(device_type type);

int device_build_info_payload(const device *dev, char *buffer, size_t buffer_len);
int device_apply_switch(device *dev,const char *label,const char *position);
int device_set_parameter(device *dev, const char *key,const char *value);

#endif