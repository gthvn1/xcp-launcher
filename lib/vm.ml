open Sexplib.Conv

type network = User | Tap [@@deriving sexp]
type disk_ty = Qcow2 | Raw [@@deriving sexp]
type disk = { ty : disk_ty; path : string } [@@deriving sexp]
type redir_ty = Udp | Tcp [@@deriving sexp]

type redirection = { ty : redir_ty; port_host : int; port_vm : int }
[@@deriving sexp]

type check_error =
  | Duplicated_port of int
  | Missing_file of string
  | Tap_not_found of string

type vm = {
  base_dir : string; (* this is where we will look for disks for example *)
  description : string;
  name : string;
  memory : int;
  cores : int;
  uefi_vars : string;
  disks : disk list;
  network : network;
  redirections : redirection list;
}
[@@deriving sexp]

module IntSet = Set.Make (Int)

let vm_files_dir (vm : vm) : string =
  (* TODO: HOME is already checked in main, we can probably pass it as a parameter from main *)
  match Sys.getenv_opt "HOME" with
  | Some d -> Filename.concat d vm.base_dir
  | None -> failwith "HOME doesn't exist"

(* HELPERS *)
let qcow2 path = { ty = Qcow2; path }
let raw path = { ty = Raw; path }
let tcp ~host ~guest = { ty = Tcp; port_host = host; port_vm = guest }
let udp ~host ~guest = { ty = Udp; port_host = host; port_vm = guest }
let name vm = vm.name
let desc vm = vm.description

(* The trailing string is the VM name. Making the name the final positional
   argument is deliberate: OCaml only "commits" optional arguments when a
   non-optional argument is applied after them, so you need something non-optional
   at the end. Since name fills that role, callers don't need the awkward
   trailing ()
  *)
let make ?(description = "") ?(memory = 4096) ?(cores = 2) ?(disks = [])
    ?(network = User) ?(redirections = []) ~base_dir ~uefi_vars name =
  {
    base_dir;
    description;
    name;
    memory;
    cores;
    uefi_vars;
    disks;
    network;
    redirections;
  }

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
        "virtio-blk-pci,drive=hd" ^ disk_id;
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

(* TODO: support more than one interface in TAP mode. Currently we are using
 tap-<vm.name> *)
let network_to_args (vm : vm) : string list =
  [ "-device"; "virtio-net-pci,netdev=net0" ]
  @
  match vm.network with
  | User -> redirections_to_args vm.redirections
  | Tap ->
      [
        "-netdev";
        "tap,id=net0,ifname=tap-" ^ vm.name ^ ",script=no,downscript=no";
      ]

(* CHECKS *)
let duplicate_ints (lst : int list) : int list =
  let rec loop acc = function
    | [] | [ _ ] -> acc
    | a :: b :: xs ->
        if a = b then loop (IntSet.add a acc) xs else loop acc (b :: xs)
  in
  loop IntSet.empty (List.sort Int.compare lst) |> IntSet.to_list

let check_taps (vms : vm list) : check_error list =
  vms
  |> List.filter_map (fun vm ->
      match vm.network with
      | Tap ->
          if Sys.file_exists ("/sys/class/net/tap-" ^ vm.name) then None
          else Some (Tap_not_found ("tap-" ^ vm.name))
      | User -> None)

let check_host_ports (vms : vm list) : check_error list =
  List.map (fun vm -> vm.redirections) vms
  |> List.concat
  |> List.map (fun r -> r.port_host)
  |> duplicate_ints
  |> List.map (fun dup_port -> Duplicated_port dup_port)

let check_files_path (vms : vm list) : check_error list =
  (* First check the disks *)
  vms
  |> List.map (fun vm ->
      let vm_dir = vm_files_dir vm in
      (* We check that paths to NVRAM and disks are accessible *)
      Filename.concat vm_dir vm.uefi_vars
      :: List.map (fun d -> Filename.concat vm_dir d.path) vm.disks)
  |> List.concat
  |> List.filter (fun f -> not (Sys.file_exists f))
  |> List.map (fun f -> Missing_file f)

let sanity_checks (vms : vm list) : (unit, check_error list) result =
  let errors = check_taps vms @ check_host_ports vms @ check_files_path vms in
  if errors = [] then Ok () else Error errors

(* EXPOSED *)
let qmp_socket_path (vm : vm) : string = "/tmp/qmp-sock-" ^ vm.name

let vm_to_args (vm : vm) : string list =
  let vm_dir = vm_files_dir vm in
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
    "-qmp";
    "unix:" ^ qmp_socket_path vm ^ ",server,wait=off";
    "-boot";
    "c";
  ]
  @ disks_to_args vm.disks vm_dir
  @ network_to_args vm
