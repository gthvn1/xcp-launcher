type network = User | Tap [@@deriving sexp]
type redirection [@@deriving sexp]

type check_error =
  | Duplicated_port of int
  | Missing_file of string
  | Tap_not_found of string

type disk [@@deriving sexp]
type t [@@deriving sexp]

val qcow2 : string -> disk
val raw : string -> disk
val tcp : host:int -> guest:int -> redirection
val udp : host:int -> guest:int -> redirection
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

val sanity_checks : t list -> (unit, check_error list) result
val qmp_socket_path : t -> string
val to_args : t -> string list

(* exposed for easy testing, remove it once well tested *)
val duplicate_ints : int list -> int list
