---- MODULE INSTANCE_inside_LET_fingerprint_test ----
(* Module.Elab` replaces each `INSTANCE` statement
with definitions. If the instantiated module
extends the module `TLAPS`, then the definitions
include backend pragmas (constructor `Bpragma`).

If the `INSTANCE` definition appears inside a `LET`,
then normalization of `LET` and fingerprints need
to handle `Bpragma` as a case.
*)


---- MODULE Inner ----
EXTENDS TLAPS

A == TRUE
======================


THEOREM
    LET M == INSTANCE Inner
    IN M!A
OBVIOUS  (* used to raise an assertion failure at:
    `Backend.Fingerprints.fp_let: other` *)


=====================================================
