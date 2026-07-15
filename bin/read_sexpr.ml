let () =
  print_endline
  @@ Sexplib.Sexp.to_string_hum (Xcp.Host.sexp_of_t (List.hd Xcp.Conf.hosts))
