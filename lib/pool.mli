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

val load : t -> unit
val from_sexp_file : string -> unit
val available_hosts : unit -> string list
val host_is_running : string -> bool
val start_host : string -> (unit, check_error) result
val sanity_checks : unit -> (unit, check_error) result
