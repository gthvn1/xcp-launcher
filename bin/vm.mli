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

val vm_to_args:  vm -> string list 
