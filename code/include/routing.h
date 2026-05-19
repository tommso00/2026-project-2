 #ifndef __ROUTING_H__
 #define __ROUTING_H__

 #include <stdbool.h>
 #include "protocol.h"

 //device ypes: used to prevent bulb, window, or fridge from becoming parents

 typedef enum {
    DEV_CONTROLLER,
    DEV_HUB,
    DEV_TIMER,
    DEV_BULB,
    DEV_WINDOW,
    DEV_FRIDGE,
    DEV_UNKNOWN
 } device_type;

 //routing nome: represents a single device inside the hierarchy routing table.
 typedef struct {
    int id
    int parent_id;      //the id of the logical parent (e.g., 0 for Controller)
    device_type type;   // Used to distinguish beetween Control and Interaction devices
 } routing_node;

 //routing and hierarchy function prototypes

 void routing_init(void);

 int routing_add_node(int id, device_type type);

 int routing_remove_node(int id);

 int routing_link_devices(int child_id, int parent_id);

 bool is_control_device(device_type type);

 #endif