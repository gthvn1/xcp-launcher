type running_host = { host : Host.t; pid : int; qmp_socket : string }
type t = Host.t list [@@deriving sexp]
type check_error = Duplicated_port of int | Host_error of Host.check_error

val load_pool : t -> unit
val from_sexp_file : string -> unit
val available_hosts : unit -> string list
val host_is_running : string -> bool
val start_host : string -> unit
val sanity_checks : unit -> (unit, check_error list) result
