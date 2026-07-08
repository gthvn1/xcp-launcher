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

module IntSet = Set.Make (Int)

(* CHECKS *)
let duplicate_ints (lst : int list) : int list =
  let rec loop acc = function
    | [] | [ _ ] -> acc
    | a :: b :: xs ->
        if a = b then loop (IntSet.add a acc) xs else loop acc (b :: xs)
  in
  loop IntSet.empty (List.sort Int.compare lst) |> IntSet.to_list

let check_host_ports (vms : vm list) : (unit, int list) result =
  let ports =
    List.map (fun vm -> vm.redirections) vms
    |> List.concat
    |> List.map (fun r -> r.port_host)
  in
  let dup = duplicate_ints ports in
  if List.is_empty dup then Ok () else Error dup

(* HELPERS *)
let qcow2 path = { ty = Qcow2; path }
let raw path = { ty = Raw; path }
let tcp ~host ~guest = { ty = Tcp; port_host = host; port_vm = guest }
let udp ~host ~guest = { ty = Udp; port_host = host; port_vm = guest }
let name vm = vm.name

(* The trailing string is the VM name. Making the name the final positional
   argument is deliberate: OCaml only "commits" optional arguments when a
   non-optional argument is applied after them, so you need something non-optional
   at the end. Since name fills that role, callers don't need the awkward
   trailing ()
  *)
let make ?(memory = 4096) ?(cores = 2) ?(disks = []) ?(redirections = [])
    ~base_dir ~uefi_vars name =
  { base_dir; name; memory; cores; uefi_vars; disks; redirections }

let disk_ty_to_string = function Qcow2 -> "qcow2" | Raw -> "raw"
let redir_ty_to_string = function Udp -> "udp" | Tcp -> "tcp"

let disks_to_args (disks : disk list) (vm_dir : string) : string list =
  List.mapi
    (fun id disk ->
      let disk_id = string_of_int id in
      let disk_path = Filename.concat vm_dir disk.path in
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
    | Some d -> Filename.concat d vm.base_dir
    | None -> failwith "HOME doesn't exist"
  in
  (* TODO: probably pass the OVMF path as a VM field *)
  [
    "-name";
    vm.name;
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
