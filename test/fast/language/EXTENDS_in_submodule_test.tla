---- MODULE EXTENDS_in_submodule_test ----
(* Ensure that modules listed in EXTENDS statements
that are contained in submodules are loaded by `tlapm`.
*)


---- MODULE Inner ----
EXTENDS TLAPS

======================

==========================================
