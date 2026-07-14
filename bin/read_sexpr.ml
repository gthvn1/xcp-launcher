let () =
  print_endline
  @@ Sexplib.Sexp.to_string_hum (Xcp.Vm.sexp_of_vm (List.hd Xcp.Conf.vms))
