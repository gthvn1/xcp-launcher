(* Needed to have sexpr for basic types: int, list, ... *)
open Sexplib.Conv

type running_hosts = { host : Vm.vm; pid : int; qmp_socket : string }
type pool = Vm.vm list [@@deriving sexp]

let state : running_hosts list ref = ref []
let my_pool = Conf.vms

let dump_vms (fname : string) =
  let oc = open_out fname in
  output_string oc @@ Sexplib.Sexp.to_string_hum (sexp_of_pool my_pool);
  close_out oc
