type redirection
type check_error = Duplicated_port of int | Missing_file of string
type disk
type vm

val qcow2 : string -> disk
val raw : string -> disk
val tcp : host:int -> guest:int -> redirection
val udp : host:int -> guest:int -> redirection
val name : vm -> string

val make :
  ?memory:int ->
  ?cores:int ->
  ?disks:disk list ->
  ?redirections:redirection list ->
  base_dir:string ->
  uefi_vars:string ->
  string ->
  vm

val sanity_checks : vm list -> (unit, check_error list) result
val qmp_socket_path : vm -> string
val vm_to_args : vm -> string list

(* exposed for easy testing, remove it once well tested *)
val duplicate_ints : int list -> int list
