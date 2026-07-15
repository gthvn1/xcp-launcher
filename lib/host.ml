open Sexplib.Conv

type network = User | Tap [@@deriving sexp]
type disk_ty = Qcow2 | Raw [@@deriving sexp]
type disk = { ty : disk_ty; path : string } [@@deriving sexp]
type redir_ty = Udp | Tcp [@@deriving sexp]

type redirection = { ty : redir_ty; port_host : int; port_guest : int }
[@@deriving sexp]

type check_error =
  | Duplicated_port of int
  | Missing_file of string
  | Tap_not_found of string

type t = {
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

let files_dir (host : t) : string =
  (* TODO: HOME is already checked in main, we can probably pass it as a parameter from main *)
  match Sys.getenv_opt "HOME" with
  | Some d -> Filename.concat d host.base_dir
  | None -> failwith "HOME doesn't exist"

(* HELPERS *)
let qcow2 path = { ty = Qcow2; path }
let raw path = { ty = Raw; path }
let tcp ~port_host ~port_guest = { ty = Tcp; port_host; port_guest }
let udp ~port_host ~port_guest = { ty = Udp; port_host; port_guest }
let name host = host.name
let desc host = host.description

(* The trailing string is the Host name. Making the name the final positional
   argument is deliberate: OCaml only "commits" optional arguments when a
   non-optional argument is applied after them, so you need something non-optional
   at the end. Since name fills that role, callers don't need the awkward
   trailing ()
  *)
let make ?(description = "no description") ?(memory = 4096) ?(cores = 2)
    ?(disks = []) ?(network = User) ?(redirections = []) ~base_dir ~uefi_vars
    name =
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

let disks_to_args (disks : disk list) (host_dir : string) : string list =
  List.mapi
    (fun id disk ->
      let disk_id = string_of_int id in
      let disk_path = Filename.concat host_dir disk.path in
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
    redirection.port_host redirection.port_guest

let redirections_to_args redirections : string list =
  let r = List.map redirection_to_hostfwd redirections in
  [ "-netdev"; String.concat "," ("user,id=net0" :: r) ]

(* TODO: support more than one interface in TAP mode. Currently we are using
 tap-<Host.name> *)
let network_to_args host : string list =
  [ "-device"; "virtio-net-pci,netdev=net0" ]
  @
  match host.network with
  | User -> redirections_to_args host.redirections
  | Tap ->
      [
        "-netdev";
        "tap,id=net0,ifname=tap-" ^ host.name ^ ",script=no,downscript=no";
      ]

(* CHECKS *)
let duplicate_ints (lst : int list) : int list =
  let rec loop acc = function
    | [] | [ _ ] -> acc
    | a :: b :: xs ->
        if a = b then loop (IntSet.add a acc) xs else loop acc (b :: xs)
  in
  loop IntSet.empty (List.sort Int.compare lst) |> IntSet.to_list

(* Currently we only have one tap *)
let check_tap host : check_error list =
  match host.network with
  | User -> []
  | Tap ->
      if Sys.file_exists ("/sys/class/net/tap-" ^ host.name) then []
      else [ Tap_not_found ("tap-" ^ host.name) ]

let check_all_taps (hosts : t list) : check_error list =
  List.concat_map check_tap hosts

let get_ports host : int list =
  List.map (fun r -> r.port_host) host.redirections

let check_all_ports (hosts : t list) : check_error list =
  List.concat_map get_ports hosts
  |> duplicate_ints
  |> List.map (fun dup_port -> Duplicated_port dup_port)

let check_files host : check_error list =
  let host_dir = files_dir host in
  (* First we create a list with NVRAM and disks, then we check if some are missing *)
  Filename.concat host_dir host.uefi_vars
  :: List.map (fun d -> Filename.concat host_dir d.path) host.disks
  |> List.filter_map (fun f ->
      if Sys.file_exists f then None else Some (Missing_file f))

let check_all_files (hosts : t list) : check_error list =
  List.concat_map check_files hosts

let sanity_checks (hosts : t list) : (unit, check_error list) result =
  let errors =
    check_all_taps hosts @ check_all_ports hosts @ check_all_files hosts
  in
  if errors = [] then Ok () else Error errors

(* EXPOSED *)
let qmp_socket_path host : string = "/tmp/qmp-sock-" ^ host.name

let to_args host : string list =
  let host_dir = files_dir host in
  (* TODO: probably pass the OVMF path as a VM field *)
  [
    "-name";
    host.name;
    "-enable-kvm";
    "-m";
    string_of_int host.memory;
    "-smp";
    string_of_int host.cores;
    "-vga";
    "virtio";
    "-cpu";
    "host,kvm=on";
    "-drive";
    "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd";
    "-drive";
    "if=pflash,format=raw,file=" ^ host_dir ^ "/" ^ host.uefi_vars;
    "-qmp";
    "unix:" ^ qmp_socket_path host ^ ",server,wait=off";
    "-boot";
    "c";
  ]
  @ disks_to_args host.disks host_dir
  @ network_to_args host
