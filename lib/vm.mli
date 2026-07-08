type disk_ty = Qcow2 | Raw
type disk = { ty : disk_ty; path : string }
type redir_ty = Udp | Tcp
type redirection = { ty : redir_ty; port_host : int; port_vm : int }

type vm = {
  base_dir : string; (* this is where we will look for disks for example *)
  name : string;
  memory : int;
  cores : int;
  uefi_vars : string;
  disks : disk list;
  redirections : redirection list;
}

val check_host_ports : vm list -> (unit, int list) result
val vm_to_args : vm -> string list

(* exposed for easy testing, remove it once well tested *)
val duplicate_ints : int list -> int list
