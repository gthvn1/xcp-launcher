# XCP Launcher

A small tool to start and manage a pool of XCP-ng hosts, each running as a
QEMU virtual machine, from a typed OCaml configuration.

Instead of writing a long shell script with many `qemu` options, you describe
each host as a data structure: its memory, its cores, its disks, its UEFI vars,
and its network. The tool builds the `qemu` command, runs sanity checks, and
starts the hosts.

A "host" here is an XCP-ng hypervisor running inside QEMU. The word "VM" is
reserved for the guests that will later run *inside* those hosts.

## Two ways to use it

The logic lives in the `xcp` library (`lib/`), so you can drive it either from a
one-shot launcher or interactively from a REPL.

### From the launcher

Build and run:

```shell
dune build
dune exec bin/xcp_launcher.exe
```

Describe your hosts in `lib/conf.ml`. Before starting anything, the tool runs
sanity checks on the whole pool and refuses to start if it finds a problem.

### From utop (interactive)

For interactive pool management, use `utop` with the library loaded:

```shell
dune utop
```

A `.ocamlinit` at the project root can `open Xcp` so the modules are available
without a prefix.

Typical session:

```ocaml
Pool.load_pool Pool_as_code.my_pool;;  (* or Pool.from_sexp_file "conf/pool_example.sexp" *)
Pool.available_hosts ();;              (* list hosts in the loaded pool *)
Pool.start_host "host1";;              (* start one host in the background *)
```

The REPL session keeps its state between commands, so the list of running hosts
(with their PIDs and QMP sockets) persists as long as `utop` stays open.

## Configuration

A pool can be described two ways:

- **As OCaml code** in `lib/conf.ml`, using the `Host.make` helper. Validated at
  compile time.
- **As an s-expression file**, loaded with `Pool.load_pool_from_file`. The types
  derive `sexp`, so the file maps directly onto the `Host.t` structure. Editing
  it does not require recompilation.

## Talking to a host over QMP

Once a host is running, you can talk to it over its QMP Unix socket
(`/tmp/qmp-sock-<name>`):

```shell
./_build/default/bin/qmp_test.exe /tmp/qmp-sock-host1
```

The client opens the socket, performs the QMP capabilities handshake, and can
send commands such as `query-status` and read the response.

## Sanity checks

Run on the whole pool before launch, all reported at once:

- **Duplicated host ports** across hosts (for `user` networking).
- **Missing files**: disks and UEFI vars.
- **Missing taps**: for hosts in `tap` mode, checks that the tap interface
  exists, and reports the one to create otherwise.

## Networking

Two modes per host:

- **`user`**: QEMU's built-in networking with host port redirections. Simple,
  isolated, no setup.
- **`tap`**: the host is attached to a bridge (for example libvirt's `virbr0`)
  via a tap interface named `tap-<name>`. Hosts on the same bridge can see each
  other and reach the internet through the bridge's NAT. The tap must exist
  beforehand; the sanity check reports the command to create it.

## Planned

- Finer control over multiple network interfaces per host.
- Higher-level QMP commands exposed as OCaml functions (query state, clean
  shutdown) callable from utop.
- Persistent QMP sessions kept open in the pool state.

Built with **OCaml 5**. The interactive workflow uses **utop**; the QMP client
uses plain `Unix` sockets.
