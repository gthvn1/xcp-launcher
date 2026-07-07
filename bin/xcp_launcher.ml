let qemu_system = "qemu-system-x86_64"

type disk_ty = Qcow2 | Raw
type disk = { ty : disk_ty; path : string }
type redir_ty = Udp | Tcp
type redirection = { ty : redir_ty; port_host : int; port_vm : int }

type vm = {
  name : string;
  memory : int;
  cores : int;
  disks : disk list;
  redirections : redirection list;
}

let disk_ty_to_string = function Qcow2 -> "qcow2" | Raw -> "raw"
let redir_ty_to_string = function Udp -> "udp" | Tcp -> "tcp"

let my_vm : vm =
  {
    name = "my_vm";
    memory = 4096;
    cores = 4;
    disks = [ { ty = Qcow2; path = "disk.qcow2" } ];
    redirections =
      [
        { ty = Tcp; port_host = 8022; port_vm = 22 };
        { ty = Tcp; port_host = 8443; port_vm = 443 };
        { ty = Tcp; port_host = 8080; port_vm = 80 };
      ];
  }

let disk_to_args (disk_id : int) (disk : disk) : string list =
  [
    "-drive";
    "file=" ^ disk.path ^ ",if=none,format=" ^ disk_ty_to_string disk.ty
    ^ ",id=hd" ^ string_of_int disk_id;
    "-device";
    "scsi-hd,drive=hd" ^ string_of_int disk_id;
  ]

let redirection_to_hostfwd redirection : string =
  Printf.sprintf "hostfwd=%s::%d-:%d"
    (redir_ty_to_string redirection.ty)
    redirection.port_host redirection.port_vm

let redirections_to_args redirections : string list =
  let r = List.map redirection_to_hostfwd redirections in
  [ "-netdev"; "user,id=net0," ^ String.concat "," r ]

let vm_to_args (vm : vm) : string list =
  let disks_args = List.mapi disk_to_args vm.disks |> List.concat in
  [
    "-enable-kvm";
    "-m";
    string_of_int vm.memory;
    "-smp";
    string_of_int vm.cores;
    "-vga";
    "virtio";
    "-cpu";
    "host,kvm=on";
    "-drive";
    "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd";
    "-drive";
    "if=pflash,format=raw,file=./my_vars.fd";
    "-device";
    "virtio-scsi-pci,id=scsi";
    "-device";
    "e1000,netdev=net0";
    "-boot";
    "c";
  ]
  @ disks_args
  @ redirections_to_args vm.redirections

let main out proc_mgr =
  Eio.Process.run proc_mgr [ qemu_system; "--version" ];
  let cmd = String.concat " " (qemu_system :: vm_to_args my_vm) in
  Eio.Flow.copy_string (cmd ^ "\n") out

let () =
  Eio_main.run (fun env ->
      main (Eio.Stdenv.stdout env) (Eio.Stdenv.process_mgr env))
