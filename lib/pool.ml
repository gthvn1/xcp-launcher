(* Needed to have sexpr for basic types: int, list, ... *)
open Sexplib.Conv

type running_host = { host : Host.t; pid : int; qmp_socket : string }
type pool = Host.t list [@@deriving sexp]

let state : running_host list ref = ref []
let pool_cache : pool option ref = ref None
let msg_load_pool = "You need to load a pool from s-exp or conf"

let load_pool_from_file (fname : string) =
  pool_cache := Some (Sexplib.Sexp.load_sexp fname |> pool_of_sexp)

let load_pool_from_conf () = pool_cache := Some Conf.hosts

let available_hosts () =
  match !pool_cache with
  | None -> print_endline msg_load_pool
  | Some pool ->
      List.iter
        (fun (h : Host.t) ->
          Printf.printf "%s: %s\n" (Host.name h) (Host.desc h))
        pool

let host_is_running (name : string) : bool =
  List.exists (fun rh -> Host.name rh.host = name) !state

let start_host (name : string) =
  if Option.is_none !pool_cache then failwith msg_load_pool;
  let pool = Option.get !pool_cache in
  if host_is_running name then failwith "Host is already running";
  (* Check of the VM is in the pool *)
  match List.filter (fun h -> Host.name h = name) pool with
  | [] -> failwith ("Host " ^ name ^ " not found in the pool")
  | [ host ] ->
      let cmd = "qemu-system-x86_64" in
      (* The first element of the array must be the command *)
      let args = Array.of_list (cmd :: Host.to_args host) in
      let open Unix in
      let pid = create_process cmd args stdin stdout stderr in
      state := { host; pid; qmp_socket = Host.qmp_socket_path host } :: !state
  | _ -> failwith ("There is more than one host named " ^ name)
