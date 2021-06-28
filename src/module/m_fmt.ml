(*
 * module_fmt.ml --- modules (formatting)
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext

open Property
open Util.Coll

open Expr.T

open M_t

open Format
open Fmtutil

open Expr.Fmt

let pp_print_shaped ff (n, shp) =
  fprintf ff "%s%a" n pp_print_shape shp

let rec pp_print_modunit ?(force=false) cx ff mu = match mu.core with
  | Constants [c, shp] ->
      let (ncx, c) = adj cx c in
      fprintf ff "@[<b2>CONSTANT@ %s%a@]@,"
        c pp_print_shape shp ;
      ncx
  | Constants cs ->
      let ns = List.map fst cs in
      let (ncx, ns) = adjs cx ns in
      let cs = List.map2 (fun n (_, shp) -> (n, shp)) ns cs in
      fprintf ff "@[<b2>CONSTANTS@ %a@]@,"
        (pp_print_delimited pp_print_shaped) cs ;
      ncx
  | Recursives cs ->
      let ns = List.map fst cs in
      let (ncx, ns) = adjs cx ns in
      let cs = List.map2 (fun n (_, shp) -> (n, shp)) ns cs in
      fprintf ff "@[<b2>RECURSIVE@ %a@]@,"
        (pp_print_delimited pp_print_shaped) cs ;
      ncx
  | Variables vs ->
      let (ncx, vs) = adjs cx vs in
      fprintf ff "@[<b2>VARIABLE%s@ %a@]@,"
        (if ((List.length vs) = 1) then "" else "S")
        (pp_print_delimited pp_print_string) vs ;
      ncx
  | Definition (df, wd, _, ex) ->
      let nm = match df.core with
        | Operator (nm, _) | Instance (nm, _) | Bpragma (nm, _, _)
        | Recursive (nm, _)
        -> nm
      in
      let (ncx, nm) = adj cx nm in
      if force || Params.debugging "alldefs" || wd <> Builtin then
        fprintf ff
          "@[<b0>%t%s%t@]@,"
          (fun ff -> if ex = Local then pp_print_string ff "LOCAL ")
          (if wd = Builtin then "(* builtin *) " else "")
          (fun ff -> ignore (Expr.Fmt.pp_print_defn cx ff df)) ;
      ncx
  | Axiom (None, e) ->
      fprintf ff "@[<b2>AXIOM@ %a@]@," (pp_print_expr cx) e ;
      bump cx
  | Axiom (Some nm, e) ->
      let (ncx, nm) = adj cx nm in
      fprintf ff "@[<b2>AXIOM@ %s ==@ %a@]@,"
        nm (pp_print_expr cx) e ;
      bump ncx
  | Theorem (None, sq, _, prf, prf_orig, summ) ->
      fprintf ff "@[<v0>@[<b2>THEOREM@ " ;
      let pcx = pp_print_sequent cx ff sq in
        fprintf ff "@]@,@[<b2>%a@]@]@,"
          (Proof.Fmt.pp_print_proof pcx) prf ;
        bump cx
  | Theorem (Some nm, sq, _, prf, prf_orig, summ) ->
      let (ncx, nm) = adj cx nm in
      fprintf ff "@[<v0>@[<b2>THEOREM@ %s ==@ " nm ;
      let _ = pp_print_sequent cx ff sq in
      let pcx = Deque.fold_left begin
        fun cx h -> fst (adj cx (hyp_name h @@ h))
      end ncx sq.context in
      fprintf ff "@]@,@[<b2>%a@]@]@,"
        (Proof.Fmt.pp_print_proof pcx) prf ;
      bump ncx
  | Submod m ->
      fprintf ff "  @[<h>%a@]@\n" (pp_print_module cx) m ;
      cx
  | Mutate (uh, us) ->
      fprintf ff "@[<h>%s %a@]@,"
        (match uh with
           | `Use false -> "USE"
           | `Use true -> "(*{_}*)USE"
           | _ -> "HIDE")
        (Proof.Fmt.pp_print_usable cx) us ;
      if uh = `Hide then cx else
        List.fold_left begin
          fun cx _ -> bump cx
        end cx us.Proof.T.facts
  | Anoninst (ins, loc) ->
      fprintf ff "@[%t%a@]@,"
        (fun ff -> if loc = Local then fprintf ff "LOCAL " else ())
        (pp_print_instance cx) ins ;
      cx

and pp_print_module ?(force=false) cx ff m =
  fprintf ff "@[<v0>---- MODULE %s ----@," m.core.name.core ;
  begin match m.core.stage with
    | Parsed when m.core.extendees <> [] ->
        fprintf ff "EXTENDS @[<b0>%a@]@,"
          (pp_print_delimited Util.pp_print_hint) m.core.extendees
    | Flat -> fprintf ff "@[Flat@]@,"
    | Special -> fprintf ff "@[Special@]@,"
    | Parsed -> fprintf ff "@[Parsed with no extendees@]@,"
    | _ -> ()
  end ;
  ignore begin
    List.fold_left begin
      fun cx mu ->
        pp_print_modunit ~force:force cx ff mu
    end cx m.core.body
  end ;
  (*
   * begin match m.core.compact with
   *   | Some bnd ->
   *       fprintf ff "(\* compact: @[" ;
   *       pp_print_expr cx ff (Bundle bnd @@ m) ;
   *       fprintf ff "@] *\)@\n" ;
   *   | _ -> ()
   * end ;
   *)
  fprintf ff "========@]"

let pp_print_modctx ff mcx =
  pp_open_vbox ff 0 ;
  Sm.iter
    (fun _ m ->
       pp_print_module (Deque.empty, Ctx.dot) ff m ;
       pp_print_cut ff ()) mcx ;
  pp_close_box ff ()

let summary mule = match mule.core.stage with
  | Final { final_status = (stat, summ) } ->
      printf "@[<v0>---- summary of module %S ----@," mule.core.name.core ;
      printf "  obligations_count = %d@," summ.sum_total ;
      if fst summ.sum_suppressed <> 0 && !Params.verbose then
        printf "  suppressed_obligations_count = %d@," (fst summ.sum_suppressed) ;
      if fst summ.sum_absent <> 0 then
        printf "  missing_proofs_count = %d@," (fst summ.sum_absent) ;
      if fst summ.sum_omitted <> 0 then
        printf "  omitted_proofs_count = %d@," (fst summ.sum_omitted) ;
      let no_miss = ref 0 in
      let no_om = ref 0 in
      List.iter begin
        fun mu -> match mu.core with
          | Theorem (_, _, _, pf, pf_orig, summ) -> begin match pf.core with
              | Proof.T.Omitted (Proof.T.Elsewhere _) -> ()
              | _ ->
                  if fst summ.sum_absent + fst summ.sum_omitted > 0 then begin
                    printf "  @[<v0>---- incomplete proof of theorem at %s ----@,"
                      (Loc.string_of_locus_nofile (Loc.left_of (Util.get_locus mu))) ;
                    if fst summ.sum_absent > 0 then begin
                      printf "  missing_proofs_count = %d@," (fst summ.sum_absent) ;
                      List.iter begin
                        fun loc ->
                          incr no_miss;
                          printf "  missing_proof_%d at %s@,"
                            !no_miss (Loc.string_of_locus_nofile loc)
                      end (snd summ.sum_absent)
                    end ;
                    if fst summ.sum_omitted > 0 then begin
                      printf "  omitted_proofs_count = %d@," (fst summ.sum_omitted) ;
                      List.iter begin
                        fun loc ->
                          incr no_om ;
                          printf "  omitted_proof_%d at %s@,"
                            !no_om (Loc.string_of_locus_nofile loc)
                      end (snd summ.sum_omitted)
                    end ;
                    printf "====@]@,"
                  end
            end
          | _ -> ()
      end mule.core.body ;
      printf "====@]@."
  | _ -> ()
