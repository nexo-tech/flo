(lang dune 3.16)

(name flo)

(version 0.1.0)

(generate_opam_files true)

(source
 (github anthropics/flo))

(authors "Flo Contributors")

(maintainers "Flo Contributors")

(license MIT)

(package
 (name flo)
 (synopsis "A modern logging library for Eio-based OCaml 5 applications")
 (description "Flō combines Loguru's ergonomics with Haskell's functional elegance and modern observability standards. Features structured logging, distributed tracing, fiber-local context propagation, and zero-cost abstractions.")
 (depends
  (ocaml (>= 5.1.0))
  (dune (>= 3.16))
  (eio (>= 1.0))
  (eio_main (>= 1.0))
  (yojson (>= 2.0.0))
  (ptime (>= 1.0.0))
  (alcotest (and (>= 1.7.0) :with-test))))
