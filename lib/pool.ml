(* Needed to have sexpr for basic types: int, list, ... *)
open Sexplib.Conv

type running_host = { host : Host.t; pid : int; qmp_socket : string }
type t = Host.t list [@@deriving sexp]
type sanity_error = Duplicated_port of int | Host_error of Host.check_error

type runtime_error =
  | Host_not_found of string
  | Host_already_running of string
  | Duplicate_host_name of string

type check_error =
  | Empty_pool
  | Sanity of sanity_error list
  | Runtime of runtime_error

(* We are using global variable so we can run everything from utop that is
   our REPL. *)
let state : running_host list ref = ref []
let pool_cache : t option ref = ref None
let load (pool : t) : unit = pool_cache := Some pool

let with_pool (f : t -> ('a, check_error) result) : ('a, check_error) result =
  match !pool_cache with None -> Error Empty_pool | Some pool -> f pool

let from_sexp_file (fname : string) =
  load (Sexplib.Sexp.load_sexp fname |> t_of_sexp)

let available_hosts () : string list =
  match !pool_cache with
  | None -> []
  | Some pool -> List.map (fun (h : Host.t) -> Host.name h) pool

let host_is_running (name : string) : bool =
  List.exists (fun rh -> Host.name rh.host = name) !state

let start_host (name : string) =
  with_pool @@ fun pool ->
  if host_is_running name then Error (Runtime (Host_already_running name))
  else
    (* Check of the host is in the pool *)
    match List.filter (fun h -> Host.name h = name) pool with
    | [] -> Error (Runtime (Host_not_found name))
    | [ host ] ->
        let cmd = "qemu-system-x86_64" in
        (* The first element of the array must be the command *)
        let args = Array.of_list (cmd :: Host.to_args host) in
        let open Unix in
        let pid = create_process cmd args stdin stdout stderr in
        state := { host; pid; qmp_socket = Host.qmp_socket_path host } :: !state;
        Ok ()
    | _ -> Error (Runtime (Duplicate_host_name name))

(* CHECKS *)
module IntSet = Set.Make (Int)

let duplicate_ints (lst : int list) : int list =
  let rec loop acc = function
    | [] | [ _ ] -> acc
    | a :: b :: xs ->
        if a = b then loop (IntSet.add a acc) xs else loop acc (b :: xs)
  in
  loop IntSet.empty (List.sort Int.compare lst) |> IntSet.to_list

let check_all_files pool : sanity_error list =
  List.concat_map Host.check_files pool |> List.map (fun e -> Host_error e)

let check_all_ports pool : sanity_error list =
  List.concat_map Host.get_ports pool
  |> duplicate_ints
  |> List.map (fun dup_port -> Duplicated_port dup_port)

let check_all_taps pool : sanity_error list =
  List.concat_map Host.check_tap pool |> List.map (fun e -> Host_error e)

let sanity_checks () : (unit, check_error) result =
  with_pool @@ fun p ->
  let errors = check_all_taps p @ check_all_ports p @ check_all_files p in
  if errors = [] then Ok () else Error (Sanity errors)
