(*
 * encode/axiomatize.mli --- add axioms in a sequent
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Expr.T

open N_table

(** Extended context
    Adding new hypotheses in the context is tricky because De Bruijn
    indexes are involved.  The solution adopted here is to add new hypotheses
    only at the top, following this order:
        New Declarations, New Axioms, Original Hyps |- Original Goal

    That way, no complicated shifting is necessary in the original sequent.
*)
type ectx = SmbSet.t * expr Deque.dq


(* {3 Main} *)

(** Collect relevant symbols and axioms *)
val collect : sequent -> ectx

(** Assemble a sequent with an extended context *)
val assemble : ectx -> sequent -> sequent

