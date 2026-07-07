# XCP Launcher

A small tool to start XCP-ng virtual machines from a typed configuration.

Instead of writing a long shell script with many `qemu` options, you describe each
VM as a data strucuture in OCaml: its memory, its cores, its disks, and its network
port redirections. The program reads the configuration and builds the `qemu` command
for you.

The goal is to run a small pool of VMs (for example, three hosts) with fine control over
the network.

## Planned features

- **A shell** to control VMs. After a VM start, you can send commands to stop it or check its
state from OCaml, instead of killing the process by hand.
- **QMP support**. QMP (Qemu Machine Protocol) let's you talk to a running VM through a socket.
You send JSON commands to query the VM, manage its devices, or shut it down cleanly.

The project is built with **OCaml 5** and **Eio**, so it can supervise several VMs at the
same time using concurrent tasks.
