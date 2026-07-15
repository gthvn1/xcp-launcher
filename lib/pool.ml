(* Needed to have sexpr for basic types: int, list, ... *)
open Sexplib.Conv

type running_hosts = { host : Vm.vm; pid : int; qmp_socket : string }
type pool = Vm.vm list [@@deriving sexp]

let state : running_hosts list ref = ref []
let pool_cache : pool option ref = ref None
let msg_load_pool = "You need to load a pool from s-exp or conf"

let load_pool_from_file (fname : string) =
  pool_cache := Some (Sexplib.Sexp.load_sexp fname |> pool_of_sexp)

let load_pool_from_conf () = pool_cache := Some Conf.vms

let available_vms () =
  match !pool_cache with
  | None -> print_endline msg_load_pool
  | Some pool ->
      List.iter
        (fun (vm : Vm.vm) -> Printf.printf "%s: %s\n" (Vm.name vm) (Vm.desc vm))
        pool

let running_vms () =
  List.iter
    (fun h -> Printf.printf "%s %d %s\n" (Vm.name h.host) h.pid h.qmp_socket)
    !state

let vm_is_running (name : string) : bool =
  List.exists (fun h -> Vm.name h.host = name) !state

let start_vm (name : string) =
  if Option.is_none !pool_cache then failwith msg_load_pool;
  let pool = Option.get !pool_cache in
  if vm_is_running name then failwith "VM is already running";
  (* Check of the VM is in the pool *)
  match List.filter (fun vm -> Vm.name vm = name) pool with
  | [] -> failwith ("VM " ^ name ^ " not found in the pool")
  | [ vm ] ->
      let cmd = "qemu-system-x86_64" in
      (* The first element of the array must be the command *)
      let args = Array.of_list (cmd :: Vm.vm_to_args vm) in
      let open Unix in
      let pid = Unix.create_process cmd args stdin stdout stderr in
      let host = { host = vm; pid; qmp_socket = Vm.qmp_socket_path vm } in
      state := host :: !state
  | _ -> failwith ("There is more than one VM named " ^ name)
