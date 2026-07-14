# XCP Launcher

A small tool to start XCP-ng virtual machines from a typed configuration.

Instead of writing a long shell script with many `qemu` options, you describe each
VM as a data structure in OCaml: its memory, its cores, its disks, and its network
port redirections. The program reads the configuration and builds the `qemu` command
for you.

The goal is to run a small pool of VMs (for example, three hosts) with fine control over
the network.

## Build & Run

Build both executables:

```shell
dune build
```

This produces `xcp_launcher.exe` (the launcher) and `qmp_test.exe` (a small QMP client).

Describe your VMs in `lib/conf.ml`, then start them:

```shell
./_build/default/bin/xcp_launcher.exe
```

Before launching anything, the tool runs sanity checks on the whole pool and
refuses to start if it finds a problem (see below).

Once a VM is running, you can talk to it over QMP:

```shell
❯ ./_build/default/bin/qmp_test.exe /tmp/qmp-sock-vm1
First we need to read the greeting from Qemu
Got: {"QMP": {"version": {"qemu": {"micro": 11, "minor": 0, "major": 10}, "package": "Debian 1:10.0.11+ds-0+deb13u1"}, "capabilities": ["oob"]}}
now we can send the get_capabilities
Got: {"return": {"status": "running", "running": true}}
```

## Features

- **Typed configuration**. Each VM is an OCaml record (memory, cores, disks,
  UEFI vars, port redirections). Invalid fields are caught at compile time.
- **Sanity checks before launch**. The pool is validated up front, and nothing
  starts if any check fails. All problems are reported at once, so you don't
  fix them one restart at a time. Current checks: duplicated host ports across
  VMs, and missing files (disks and UEFI vars).
- **Concurrent launch**. Several VMs are started concurrently using Eio fibers.
- **QMP support (basic)**. QMP (QEMU Machine Protocol) lets you talk to a running
  VM through a Unix socket. The client opens a session, performs the capabilities
  handshake, and can send commands (for example `query-status`) and read the
  response.

## Planned features

- **An interactive shell** to control VMs: send commands to query state or shut a
  VM down cleanly from OCaml, instead of killing the process by hand.
- **Proper JSON handling** for QMP requests and responses (currently exchanged as
  raw strings).
- **Finer network control**, moving beyond QEMU `user` networking so that VMs in a
  pool can see each other (tap/bridge).

The project is built with **OCaml 5** and **Eio**, so it can supervise several VMs at the
same time using concurrent tasks.
