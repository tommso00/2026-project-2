# Domotics OS Project

Emulated home automation system for the Operating Systems laboratory project, implemented in **C** and **Bash**, where every device is represented by a dedicated OS process and coordinated through IPC in a flat process model with a logical control hierarchy.[1]

## Overview

This project implements a domotics platform in which the `controller` process is the unique OS-level parent of all devices, while links between devices define a separate logical hierarchy used for command propagation and state queries.[1] Control devices such as the Controller, Hub, and Timer forward commands to their logical children, while interaction devices such as Bulb, Window, and Fridge expose their local state and support manual overrides.[1]

The architecture is designed around the assignment requirements: inter-process communication, concurrent handling of shell commands and child events, runtime routing updates after `link` operations, graceful error handling, and recovery from edge cases such as crashes, invalid hierarchies, and conflicting manual actions.[1]

## Goals

The project is built to satisfy the core specification of the Operating Systems laboratory assignment:[1]

- Each device is a distinct process with its own local state.[1]
- The process hierarchy is flat, but the control hierarchy is logical and maintained through IPC.[1]
- The controller must accept interactive commands and remain responsive while child devices send asynchronous updates.[1]
- Manual interaction must bypass the controller and communicate directly with the target device.[1]
- Devices must simulate processing latency with a random delay before replying to IPC commands.[1]
- Errors and exceptional situations must be handled through explicit return codes.[1]

## Repository structure

```text
.
├── code
│   ├── include
│   │   ├── cleanup.h
│   │   ├── commands.h
│   │   ├── common.h
│   │   ├── controller.h
│   │   ├── device.h
│   │   ├── error_codes.h
│   │   ├── event_loop.h
│   │   ├── ipc.h
│   │   ├── parser.h
│   │   ├── protocol.h
│   │   ├── repl.h
│   │   ├── routing.h
│   │   ├── serialization.h
│   │   └── utils.h
│   ├── Makefile
│   ├── runtime
│   │   ├── fifos
│   │   ├── logs
│   │   ├── pids
│   │   ├── registry
│   │   └── test_outputs
│   │       └── test_linking.fifo
│   ├── scripts
│   │   ├── cleanup_ipc.sh
│   │   ├── manual_interaction.sh
│   │   ├── run_basic_scenario.sh
│   │   ├── run_crash_scenario.sh
│   │   ├── run_demo.sh
│   │   └── run_override_scenario.sh
│   ├── src
│   │   ├── controller
│   │   │   ├── commands.c
│   │   │   ├── controller.c
│   │   │   ├── main.c
│   │   │   ├── parser.c
│   │   │   └── repl.c
│   │   ├── core
│   │   │   ├── device_common.c
│   │   │   ├── errors.c
│   │   │   ├── hierarchy.c
│   │   │   ├── routing.c
│   │   │   └── serialization.c
│   │   ├── devices
│   │   │   ├── bulb.c
│   │   │   ├── fridge.c
│   │   │   ├── hub.c
│   │   │   ├── timer.c
│   │   │   └── window.c
│   │   ├── ipc
│   │   │   ├── event_loop.c
│   │   │   ├── fifo.c
│   │   │   ├── ipc_common.c
│   │   │   ├── message.c
│   │   │   └── request_reply.c
│   │   ├── manual
│   │   │   └── manual_client.c
│   │   └── utils
│   │       ├── cleanup.c
│   │       ├── error_codes.c
│   │       └── random_delay.c
│   └── tests
│       ├── alltests_end2end.sh
│       ├── run_all_tests.sh
│       ├── test_cascade_delete.sh
│       ├── test_crash_handling.sh
│       ├── test_cycle_detection.sh
│       ├── test_override.sh
│       └── test_timer_validation.sh
└── report.pdf
```

## Main components

### `code/include/`
Header files that define the public interfaces of the project: controller commands, common device abstractions, IPC primitives, parsing, routing, serialization, cleanup routines, and shared error codes. This folder acts as the contract layer between modules and keeps the codebase consistent and modular.

### `code/src/controller/`
Contains the implementation of the main controller process and its command-line shell. In particular:

- `main.c` starts the controller.
- `controller.c` manages controller lifecycle and high-level coordination.
- `repl.c` implements the interactive shell loop.
- `parser.c` parses user input into validated commands.
- `commands.c` executes shell actions such as add, link, switch, list, info, and delete.

### `code/src/core/`
Core logic shared across the whole system. This area typically centralizes device-independent behavior such as:

- common device state handling,
- hierarchy validation,
- logical parent/child relationships,
- routing updates after dynamic links,
- message serialization and deserialization,
- shared error translation.

### `code/src/devices/`
Implementations of the supported device processes:

- `bulb.c` for on/off light devices.
- `window.c` for open/close windows with impulsive controls.
- `fridge.c` for a richer interaction device with temperature, fill percentage, auto-close delay, and open time tracking.[1]
- `hub.c` for a control node that mirrors and propagates child state, while reporting manual overrides when children diverge.[1]
- `timer.c` for scheduled control of a single logical branch using begin/end activation times.[1]

### `code/src/ipc/`
IPC infrastructure used by the controller and all devices. The presence of dedicated modules for FIFOs, event loops, messages, and request/reply patterns suggests a layered communication design where low-level transport is separated from protocol handling and asynchronous processing.

### `code/src/manual/`
Manual interaction client used to simulate a local physical action that bypasses the controller, as requested by the assignment.[1] This is the entry point for testing manual override scenarios and direct writes to device endpoints.[1]

### `code/src/utils/`
Utility implementations for cleanup, shared error-code helpers, and randomized response delays. The random delay module is especially important because each device must wait between 1 and 3 seconds before answering IPC requests, to simulate concurrent real-world processing.[1]

### `code/scripts/`
Operational scripts to simplify demos and reproducible scenarios:

- `cleanup_ipc.sh` removes leftover IPC resources.
- `manual_interaction.sh` launches manual commands from a second terminal.[1]
- `run_basic_scenario.sh` demonstrates standard usage.
- `run_override_scenario.sh` focuses on manual override behavior.
- `run_crash_scenario.sh` stresses crash detection and recovery.
- `run_demo.sh` provides a compact end-to-end presentation flow.

### `code/tests/`
Automated test suite targeting both functionality and required edge cases from the specification:[1]

- cycle prevention (`test_cycle_detection.sh`),
- cascade deletion of control devices (`test_cascade_delete.sh`),
- crash handling (`test_crash_handling.sh`),
- manual override correctness (`test_override.sh`),
- timer validation (`test_timer_validation.sh`),
- global orchestrators (`run_all_tests.sh`, `alltests_end2end.sh`).

### `code/runtime/`
Runtime artifacts generated while the system is running or while tests are executed:

- `fifos/` for named pipes,
- `logs/` for execution traces and debugging,
- `pids/` for process bookkeeping,
- `registry/` for endpoint discovery or routing metadata used by external/manual clients,[1]
- `test_outputs/` for outputs produced by automated checks.

## Supported model

The repository reflects the domotics model described in the assignment.[1]

| Category | Entities | Notes |
|---------|----------|-------|
| Control devices | Controller, Hub, Timer | They can have logical children and propagate commands.[1] |
| Interaction devices | Bulb, Window, Fridge | They represent final actuators or sensors with device-specific state.[1] |
| External actor | Manual client | It bypasses the controller and triggers local actions directly on a device.[1] |

The system separates two different relationships:

1. **OS process hierarchy**: all devices are children of the main controller process.[1]
2. **Logical control hierarchy**: links created at runtime determine who controls whom.[1]

This distinction is central to the project because it allows dynamic reconfiguration without killing and recreating processes whenever `link id1 to id2` is executed.[1]

## Features

### 1. Interactive controller shell
The controller exposes a textual interface with commands explicitly required by the specification:[1]

- `list` — show all devices and a summary of their characteristics.[1]
- `add <device>` — spawn a new device process.[1]
- `del <id>` — remove a device; for control devices, deletion must cascade to children.[1]
- `link <id1> to <id2>` — update the logical routing graph at runtime.[1]
- `switch <id> <label> <pos>` — set a switch on a target device.[1]
- `info <id>` — print detailed information about a device.[1]

### 2. Dynamic logical linking
Linking does not rebuild the process tree. Instead, the system updates routing metadata and communication endpoints so future commands and queries flow through the new logical parent-child relationship.[1]

This is why files such as `routing.c`, `hierarchy.c`, and the registry/runtime folders are structurally important: they support validation, path updates, and endpoint discovery after topology changes.

### 3. Manual override support
A manual interaction tool can communicate directly with a device, bypassing the root controller.[1] This simulates a real person pressing a physical switch and can create divergence between a control device's expected state and the actual states of its children.[1]

When such divergence appears, control devices must detect it and report a manual override rather than a single consistent state, until a new propagated command re-synchronizes the branch.[1]

### 4. Concurrency-aware execution
The assignment requires the controller to remain responsive to shell input while handling asynchronous child events and concurrent overrides.[1] The presence of `event_loop.c` and the dedicated IPC modules suggests that the implementation addresses this requirement with an event-driven communication layer.

Each device also introduces a random 1–3 second response delay, which makes races, ordering, and fault-handling observable during tests and demonstrations.[1]

### 5. Fault tolerance and edge-case handling
The test suite indicates explicit support for the most important corner cases required by the assignment:[1]

- invalid or cyclic links,
- deletion cascades,
- simultaneous override conflicts,
- timer validation failures,
- unexpected device crashes.

A robust implementation should ensure that one crashed child does not hang a hub or the controller, and that broken IPC resources are cleaned up correctly after abnormal termination.[1]

## Build

The assignment requires a Makefile with at least `build`, `clean`, and `run` targets.[1] This repository includes `code/Makefile`, so the expected build workflow is:

```bash
cd code
make build
```

To clean compiled binaries and IPC leftovers:

```bash
cd code
make clean
```

To run the default scenario exposed by the Makefile:

```bash
cd code
make run
```

If your Makefile supports additional runtime arguments, they can usually be passed with the `ARGS` variable as suggested by the assignment.[1]

```bash
cd code
make run ARGS="..."
```

## Manual execution

The repository also contains helper scripts to launch curated scenarios. Typical examples are:

```bash
cd code
bash scripts/run_basic_scenario.sh
bash scripts/run_override_scenario.sh
bash scripts/run_crash_scenario.sh
bash scripts/run_demo.sh
```

To simulate direct user interaction from a second terminal:

```bash
cd code
bash scripts/manual_interaction.sh <device_id> <command> [parameters...]
```

This path is useful for testing local actions that intentionally bypass controller routing and trigger override conditions.[1]

## Testing

Automated validation appears to be organized in the `code/tests/` directory. A typical workflow is:

```bash
cd code
bash tests/run_all_tests.sh
```

For targeted checks, individual scripts can be executed separately:

```bash
cd code
bash tests/test_cycle_detection.sh
bash tests/test_cascade_delete.sh
bash tests/test_override.sh
bash tests/test_crash_handling.sh
bash tests/test_timer_validation.sh
```

These tests align closely with the official edge cases listed in the project specification, so they are useful both for regression testing and for preparing the final demonstration.[1]

## Runtime directories

The `runtime/` subtree is part of the operational design of the project and should generally not be edited manually while the system is running. Its role can be summarized as follows:

- `runtime/fifos/` stores named pipes used by IPC endpoints.
- `runtime/pids/` stores process identifiers for bookkeeping and cleanup.
- `runtime/registry/` stores device discovery information used for routing or manual access.[1]
- `runtime/logs/` collects execution traces.
- `runtime/test_outputs/` stores outputs generated by test scripts.

When the system is interrupted unexpectedly, the cleanup script should be used to remove stale FIFOs and residual runtime metadata before starting again.

## Design notes

Even without inspecting every source file in detail, the final tree already communicates a clean separation of concerns:

- controller-side command parsing and orchestration are isolated in `src/controller/`,
- reusable domain logic is centralized in `src/core/`,
- device-specific behavior lives in `src/devices/`,
- communication mechanics are encapsulated in `src/ipc/`,
- operational tooling and tests are kept outside the main implementation.

This structure is particularly good for an Operating Systems project because it makes concurrency, IPC, process lifecycle, and protocol responsibilities easier to reason about, test, and present.

## Suggested presentation points

For the oral exam or project demo, the repository structure naturally supports the following explanation flow:

1. Start from the assignment model: one controller, many device processes, flat OS hierarchy, logical routing over IPC.[1]
2. Show the shell commands (`add`, `link`, `switch`, `info`, `del`) and how they map to controller modules.[1]
3. Explain how linking changes routing without respawning devices.[1]
4. Demonstrate manual interaction with `manual_interaction.sh` and show an override on a Hub or Timer.[1]
5. Run a crash scenario to prove that the system detects failures and does not hang.[1]
6. Close with the automated tests that cover the required edge cases.[1]

## Files included in submission

According to the final tree, the submission currently contains:[1]

- `code/` — full source code, scripts, runtime helpers, tests, and build system.
- `report.pdf` — project report for the course submission.[1]

## Notes

This README is intentionally written to be both a repository guide and a presentation aid. It explains not only what each directory contains, but also why that part matters in the context of the domotics assignment and its operating-systems requirements.[1]