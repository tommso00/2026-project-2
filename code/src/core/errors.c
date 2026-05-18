#include "error_codes.h"

const char *error_str(int code) {
    switch (code) {
        case OK: return "OK";
        case ERR_DEVICE_NOT_FOUND: return "DEVICE_NOT_FOUND";
        case ERR_INVALID_COMMAND: return "INVALID_COMMAND";
        case ERR_IPC_FAILURE: return "IPC_FAILURE";
        case ERR_INVALID_PARAMETERS: return "INVALID_PARAMETERS";
        case ERR_LINK_FAILED: return "LINK_FAILED";
        case ERR_DEVICE_TYPE_MISMATCH: return "DEVICE_TYPE_MISMATCH";
        case ERR_ALREADY_LINKED: return "ALREADY_LINKED";
        case ERR_SELF_LINK: return "SELF_LINK";
        case ERR_CYCLE_DETECTED: return "CYCLE_DETECTED";
        case ERR_NOT_ALLOWED: return "NOT_ALLOWED";
        case ERR_CHILD_CRASHED: return "CHILD_CRASHED";
        case ERR_TIMEOUT: return "TIMEOUT";
        case ERR_INVALID_STATE: return "INVALID_STATE";
        case ERR_INVALID_TIME: return "INVALID_TIME";
        default: return "SYSTEM_ERROR";
    }
}