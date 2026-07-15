type running_host = { host : Host.t; pid : int; qmp_socket : string }
type pool = Host.t list [@@deriving sexp]
type check_error = Duplicated_port of int | Host_error of Host.check_error

val load_pool_from_file : string -> unit
val load_pool_from_conf : unit -> unit
val available_hosts : unit -> unit
val host_is_running : string -> bool
val start_host : string -> unit
val sanity_checks : pool -> (unit, check_error list) result
