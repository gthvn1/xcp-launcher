type network = User | Tap [@@deriving sexp]
type redirection [@@deriving sexp]
type check_error = Missing_file of string | Tap_not_found of string
type disk [@@deriving sexp]
type t [@@deriving sexp]

val qcow2 : string -> disk
val raw : string -> disk
val tcp : port_host:int -> port_guest:int -> redirection
val udp : port_host:int -> port_guest:int -> redirection
val name : t -> string
val desc : t -> string

val make :
  ?description:string ->
  ?memory:int ->
  ?cores:int ->
  ?disks:disk list ->
  ?network:network ->
  ?redirections:redirection list ->
  base_dir:string ->
  uefi_vars:string ->
  string ->
  t

val check_tap : t -> check_error list
val get_ports : t -> int list
val check_files : t -> check_error list
val qmp_socket_path : t -> string
val to_args : t -> string list
