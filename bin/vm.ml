type disk_ty = Qcow2 | Raw
type disk = { ty : disk_ty; path : string }
type redir_ty = Udp | Tcp
type redirection = { ty : redir_ty; port_host : int; port_vm : int }

type vm = {
  base_dir : string; (* this is where we will look for disks for example *)
  name : string;
  memory : int;
  cores : int;
  uefi_vars : string;
  disks : disk list;
  redirections : redirection list;
}

let disk_ty_to_string = function Qcow2 -> "qcow2" | Raw -> "raw"
let redir_ty_to_string = function Udp -> "udp" | Tcp -> "tcp"

let disks_to_args (disks : disk list) (vm_dir : string) : string list =
  List.mapi
    (fun id disk ->
      let disk_id = string_of_int id in
      let disk_path = vm_dir ^ "/" ^ disk.path in
      [
        "-drive";
        "file=" ^ disk_path ^ ",if=none,format=" ^ disk_ty_to_string disk.ty
        ^ ",id=hd" ^ disk_id;
        "-device";
        "scsi-hd,drive=hd" ^ disk_id;
      ])
    disks
  |> List.concat

let redirection_to_hostfwd redirection : string =
  Printf.sprintf "hostfwd=%s::%d-:%d"
    (redir_ty_to_string redirection.ty)
    redirection.port_host redirection.port_vm

let redirections_to_args redirections : string list =
  let r = List.map redirection_to_hostfwd redirections in
  [ "-netdev"; String.concat "," ("user,id=net0" :: r) ]

let vm_to_args (vm : vm) : string list =
  let vm_dir =
    match Sys.getenv_opt "HOME" with
    | Some d -> d ^ "/" ^ vm.base_dir
    | None -> failwith "HOME doesn't exist"
  in
  (* TODO: probably pass the OVMF path as a VM field *)
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
    "if=pflash,format=raw,file=" ^ vm_dir ^ "/" ^ vm.uefi_vars;
    "-device";
    "virtio-scsi-pci,id=scsi";
    "-device";
    "e1000,netdev=net0";
    "-boot";
    "c";
  ]
  @ disks_to_args vm.disks vm_dir
  @ redirections_to_args vm.redirections
