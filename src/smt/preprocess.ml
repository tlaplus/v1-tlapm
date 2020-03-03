(*
 * backend/smt/preprocess.ml --- Skolemize, simplify equalities and abstract.
 *
 * Author: Hernán Vanzetto <hernan.vanzetto@inria.fr>
 *
 * Copyright (C) 2011-2012  INRIA and Microsoft Corporation
 *)

Revision.f "$Rev: 33204 $";;

open Ext
open Property

open Expr.T
open Expr.Subst
open Expr.Visit

open Printf
open List

module B = Builtin
module Dq = Deque
module Smt = Smtcommons
module SMap = Smt.SMap
module T = Typ_t
module E = Typ_e

module Fu = Fmtutil.Minimal (Tla_parser.Prec)

let fresh_id = Smt.fresh_id
let map = List.map
let mapi = List.mapi

let ( |>> ) = Smt.( |>> )
let ( ||> ) = Smt.( ||> )

let ( $! ) = E.( $! )

(****************************************************************************)
(* Preprocessing functions																								  *)
(****************************************************************************)

(** Compute list of primed variables occuring in the sequent [sq] *)
let primed_vars sq =
  let vars = ref [] in
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.iter as super
    method expr scx e =
      match e.core with
      | Opaque s when Smt.is_prime s -> vars := s :: !vars
      | _ -> super#expr scx e
    method hyp scx h = match h.core with
      | Defn (_, _, Hidden, _)                                                (** ignore these cases *)
      | Fact (_, Hidden, _) -> Expr.Visit.adj scx h
      | _ -> super#hyp scx h
  end in
  ignore (visitor#sequent ((),sq.context) sq) ;
(* Util.eprintf "primed_vars = %s" (String.concat "," (Smt.remove_repeated !vars)) ; *)
  Smt.remove_repeated !vars

(** Compute list of operator symbols occuring in the sequent [sq] *)
let operator_symbols sq =
  let vars = ref [] in
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.iter as super
    method expr scx e =
      match e.core with
      | Ix n ->
          begin match Dq.nth ~backwards:true (snd scx) (n - 1) with
          | Some ({core = Defn ({core = Operator (h,_)},_,_,_)}) ->
							vars := h.core :: !vars
          | _ -> ()
          end
      | _ -> super#expr scx e
    method hyp scx h = match h.core with
      | Defn (_, _, Hidden, _)                                                (** ignore these cases *)
      | Fact (_, Hidden, _) -> Expr.Visit.adj scx h
      | _ -> super#hyp scx h
  end in
  ignore (visitor#sequent ((),sq.context) sq) ;
(* Util.eprintf "primed_vars = %s" (String.concat "," (Smt.remove_repeated !vars)) ; *)
  Smt.remove_repeated !vars

(** Compute list of [Opaque] expressions occuring in the sequent [sq] *)
let opaques sq =
  let vars = ref [] in
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.iter as super
    method expr scx e =
      match e.core with
      | Opaque s when not (Smt.is_prime s) && not (Smt.is_smt_kwd s) -> vars := s :: !vars
      | _ -> super#expr scx e
    method hyp scx h = match h.core with
      | Defn (_, _, Hidden, _)                                                (** ignore these cases *)
      | Fact (_, Hidden, _) -> Expr.Visit.adj scx h
      | _ -> super#hyp scx h
  end in
  ignore (visitor#sequent ((),sq.context) sq) ;
(* Util.eprintf "opaques = %s" (String.concat "," (Smt.remove_repeated !vars)) ; *)
  Smt.remove_repeated !vars

(** Change the operator identifiers in the list [ids] from hidden
		definitions to new CONSTANTs in the context of sequent [sq] *)
let make_operators_visible ids sq =
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.map as super
    method hyp scx h =
			let nm = Expr.T.hyp_name h in
			match h.core with
			| Defn (defn, wd, Hidden, ex) when List.mem nm ids ->
					let h = Fresh (nm %% [], Shape_expr, Constant, Unbounded) @@ h in
					super#hyp scx h
      | _ -> super#hyp scx h
  end in
	snd (visitor#sequent ((),sq.context) sq)

(** Inserts the list [vars] of identifiers as new CONSTANTs in the context of
    sequent [sq] *)
let insert_vars vars sq =
  let env0 = List.fold_left (fun e v -> E.adj_none e v) E.empty vars in
  let sq = app_sequent (shift (List.length vars)) sq in
  let cx = Dq.append (E.to_scx env0) sq.context in
(* Util.eprintf "inserted_vars : %s" (String.concat "," vars) ; *)
  { context = cx ; active = sq.active }

(** The type [Ctx.ident] contains a field [salt] that counts the number
		of occurrences of an identifier symbol. [Ctx.string_of_ident] is the
		string that will be actually printed, i.e. [i_1].  *)
let make_salt_explicit sq =
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.map as super
	  method bounds scx bs =
		  let _,cx = Ectx.from_hyps Ectx.dot (snd scx) in
	    let bs = List.map begin
	      fun (v, k, dom) ->
					(* let _,nm = Isabelle.adj cx v in *)
				  let cx = Ctx.push cx v.core in
			  	let nm = Ctx.string_of_ident (Ctx.front cx) in
					(nm @@ v, k, dom)
	    end bs in
			super#bounds scx bs
    method hyp scx h =
      match h.core with
      | Defn (_, _, Hidden, _)    																						(** ignore these cases *)
      | Fact (_, Hidden, _) ->
          (Expr.Visit.adj scx h, h)
      | _ -> super#hyp scx h
  end in
	snd (visitor#sequent ((),sq.context) sq)

(****************************************************************************)

(** Pre-pre-process (first step before Boolification, type synthesis, translation, ...):
    - Register record signatures in [Smt.record_signatures] and add (instances of) record extensionality axioms
    - [TODO] Register tuple signatures
    - Unroll sequents
    - Rewrite [<<a_1,...,a_n>> = <<b_1,...,b_n>>]  -->  [a_1 = b_1 /\ ... /\ a_n = b_n]
    - Rewrite [x # {}]  -->  [(\A y : ~ y \in x) => FALSE]  in conclusions
    - Insert operator symbols and primed variable symbols in the context
    - Remove [B.Unprimable] from expressions
    - Sort string elements in sets {s1,...,sn} alphabetically
	  - make_salt_explicit
    *)
let prepreproc sq =
  let app op es = Apply (Internal op %% [], es) %% [] in
  let lAnd = function [e] -> e | es -> List (And, es) %% [] in
  let is_string e = match e.core with String _ -> true | _ -> false in
  let sort_string_exp e1 e2 =
    match e1.core, e2.core with
    | String s1, String s2 -> String.compare s1 s2
    | _ -> -1
  in

  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.map as super
    method expr scx e =
      match e.core with
      | Apply ({core = Internal B.Eq}, [{core = Tuple es1} ; {core = Tuple es2}]) ->
          begin try
            lAnd (List.map (fun (x,y) -> app B.Eq [x ; y]) (List.combine es1 es2))
          with _ ->
						Internal B.FALSE @@ e
					end
      | Record res ->
          let res = Smt.rec_sort res in
          let hs,_ = List.split res in
          Smt.record_signatures := hs :: !Smt.record_signatures;
          Record (List.map (fun (s, e) -> (s, self#expr scx e)) res) @@ e
      | SetEnum es when List.for_all is_string es ->
          SetEnum (List.sort ~cmp:sort_string_exp es) @@ e
      | Sequent sq ->
					Smt.unroll_seq sq
      | Apply ({core = Internal B.Unprimable}, [ex]) ->
          ex
      | Apply ({core = Internal (B.Leadsto | B.ENABLED | B.Cdot | B.Actplus |
          B.Box _ | B.Diamond)} as op, _) ->
           Errors.warn ~at:op "ATP/SMT backend does not handle temporal logic.";
           failwith "Backend.ATP/SMT: temporal operator";
      | _ ->
          super#expr scx e
    method hyp scx h =
      match h.core with
      | Defn (_, _, Hidden, _)    																						(** ignore these cases *)
      | Fact (_, Hidden, _) ->
          (Expr.Visit.adj scx h, h)
      | _ -> super#hyp scx h
  end in
  let sq = snd (visitor#sequent ((),sq.context) sq) in

  (** Transform conclusion(s)  [x # {}]  -->  [(\A y : ~ y \in x) => FALSE]
		  (TODO: also transform all positive formulas) *)
  let c =
    match sq.active.core with
    | Apply ({core = Internal B.Neq}, ([x ; {core = SetEnum []}]
                                     | [{core = SetEnum []} ; x])) ->
        (* app B.Implies [app B.Eq [x ; SetEnum [] %% []] ; Internal B.FALSE %% []] *)
        app B.Implies [
					Quant (Forall, [ ("y"^fresh_id ()) %% [], Constant, No_domain ], app B.Neg [app B.Mem [Ix 1 %% [] ; app_expr (shift 1) x]]) %% [];
					Internal B.FALSE %% []]
    | _ -> sq.active
  in

  (** Add instances of record extensionality for signatures occurring in the obligation *)
  let rec_ext_axioms = !Smt.record_signatures
    (* |> List.filter (fun hs -> hs <> []) *)
    |> Smt.remove_repeated
    |> List.map begin fun hs ->
        let x = Ix 2 %% [] in
        let y = Ix 1 %% [] in
        let fcnapp f x = Apply (Opaque Smt.fcnapp %% [], [f ; x]) %% [] in
        let bs = [ "r1" %% [], Constant, No_domain
                 ; "r2" %% [], Constant, No_domain ] in
        let hs = List.sort ~cmp:String.compare hs in
        let hs = List.map (fun h -> String h %% []) hs in
        let ex = app B.Implies [
          lAnd ((Apply (Opaque "tla__isAFcn" %% [], [x]) %% []) ::
                (Apply (Opaque "tla__isAFcn" %% [], [y]) %% []) ::
                (app B.Eq [app B.DOMAIN [x] ; SetEnum hs %% []]) ::
                (app B.Eq [app B.DOMAIN [y] ; SetEnum hs %% []]) ::
                (map (fun h -> app B.Eq [ fcnapp x h ; fcnapp y h ]) hs)
               );
          app B.Eq [x ; y]
        	] in
        Quant (Forall, bs, ex) %% []
      end
  in
  let c = List.fold_left (fun r a -> app B.Implies [a ; r]) c rec_ext_axioms in
  let sq = { sq with active = c } in
(* Util.eprintf "[1.1]: %a" Fu.pp_print_minimal (Fu.Big (fun ff -> ignore (E.pp_print_sequent (sq.context, Ctx.dot) ff sq))); *)
(* Util.eprintf "//operator_symbols = %s" (String.concat "," (operator_symbols sq)); *)
(* Util.eprintf "//primed_vars = %s" (String.concat "," (primed_vars sq)); *)
  sq
	|> make_operators_visible (operator_symbols sq)															(** Operator identifiers need to appear explicitly in the sequent in order to be declared *)
	|> insert_vars (primed_vars sq)																							(** ... the same for identifiers of primed variables *)
	|> insert_vars (opaques sq)					    																		(** ... the same for other opaque expressions *)
  |> make_salt_explicit

(****************************************************************************)
(* Uncurry + Skolemize conclusion                                           *)
(*   [n] = counter for the number of bound variables                        *)
(****************************************************************************)
let rec uncurry sq n =
  match sq.active.core with
  | Apply ({core = Internal B.Implies}, [hs ; c]) ->
      let hs = hs
        |> Smt.deconj
        |> mapi (fun i -> app_expr (shift i))
        |> map (fun e -> Fact (e, Visible, NotSet) @@ e)
      in
      let scx = snd (Expr.Visit.adjs ((),sq.context) hs) in
      let c = app_expr (shift (List.length hs)) c in
      let sq = { context = scx ; active = c } in
      uncurry sq n
  | Quant (Forall, bs, c) ->
(* Util.eprintf "Skolem Fact: %a" (Typ_e.pp_print_expr (sq.context, Ctx.dot)) sq.active; *)
      (* let ecx = Ectx.from_hyps Ectx.dot sq.context in                        (** creates [ecx] from [sq.context] *)
      let (scx,_),_,hs = Ectx.adj_bs ecx bs in *)
      let hs = Ectx.to_fresh bs in
      let cx = snd (Expr.Visit.adjs ((),sq.context) hs) in
(* Util.eprintf "       Fact: %a" (Typ_e.pp_print_expr (scx, Ctx.dot)) c; *)
      let sq = { context = cx ; active = c } in
      uncurry sq (n + List.length hs)
  | _ ->
      sq, n

(****************************************************************************)
(* Skolemize and deconj hypotheses + [uncurry]                              *)
(*   FIX: Suppose two hypotheses [\E i: P(i)] and [\E i: Q(i)]. The first   *)
(*   one is skolemized as [NEW i; P(i)] while the second as [NEW i; Q(i_1)].*)
(****************************************************************************)
let rec skolemize_once sq =
  let rec skol (cx:unit Expr.Visit.scx) h hs =
	  (** Returns [(cx, ks, hs)] where:
	      [cx] = new context including the new hypotheses [ks]
	      [ks] = list of new hypotheses replacing [h]
	      [hs] = rest of hypotheses, shifted
	      *)
    match h.core with
    | Fact ({core = Quant (Exists, bs, ex)}, Visible, tm) ->
(* Util.eprintf "       Fact: %a" (Expr.Fmt.pp_print_expr (snd cx, Ctx.dot)) (Quant (Exists, bs, ex) @@ h); *)
        let bs = Smt.unditto bs in
        let h = Fact (ex, Visible, tm) @@ h in
        let ks = Ectx.to_fresh bs @ [h] in                                    (** [ks] = new hypotheses *)
        let cx = Expr.Visit.adjs ((),sq.context) ks in
        let n = List.length ks - 1 in                                         (** [n] = number of new hypotheses; the 1 corresponds to [h] *)
        let hs = Dq.map (fun i -> app_hyp (bumpn i (shift n))) hs in          (** apply [shift n] only to the ids that are higher than [i] *)
        cx, ks, hs

    (* | Fact ({core = Quant (Exists, bs, ex)}, Visible, tm) ->
Util.eprintf "       Fact: %a" (Typ_e.pp_print_expr (snd cx, Ctx.dot)) (Quant (Exists, bs, ex) @@ h);
        let bs = Smt.unditto bs in
        let h = Fact (ex, Visible, tm) @@ h in

        let ecx = Ectx.from_hyps Ectx.dot (snd cx) in                         (** creates [ecx] from [cx] *)
        let ecx,vss,js = Ectx.adj_bs ecx bs in                                (** [js] = new hypotheses from bounds [bs]. Through [ecx], variable ids maintain [Ctx salt] *)
        (* let js = mapi (fun i -> app_hyp (shift i)) js in *)

let ex' = app_expr (bumpn (Dq.size hs) (shift (List.length bs))) ex in
let vs = map fst vss in
Util.eprintf "Skolem \\E %s : %a" (String.concat "," vs) (Typ_e.pp_print_expr ecx) ex';
Util.eprintf "Skolem \\E %s : %a" (String.concat "," vs) (Typ_e.pp_print_expr (fst ecx, Ctx.dot)) ex';
let cx' = Expr.Visit.adjs cx js in
Util.eprintf "Skolem \\E %s : %a" (String.concat "," vs) (Typ_e.pp_print_expr (snd cx', Ctx.dot)) ex';


        (* let cx = Expr.Visit.adjs cx ks in *)
        let ecx,(_,h) = Ectx.adj ecx h in
        let ks = js @ [h] in

(* let ks = Ectx.to_fresh bs @ [h] in *)
let cx' = Expr.Visit.adjs cx' [h] in

        let n = List.length ks - 1 in                                         (** [n] = number of new hypotheses; the 1 corresponds to [h] *)
        let hs = Dq.map (fun i -> app_hyp (bumpn i (shift n))) hs in          (** apply [shift n] only to the ids that are higher than [i] *)

        (* ((),fst ecx), ks, hs *)
        cx', ks, hs *)

    (** Deconj *)
    | Fact ({core = Apply ({core = Internal B.Conj}, es)}, Visible, tm)
    | Fact ({core = List (And, es)}, Visible, tm) ->
(* Util.eprintf "Conj Fact: %a" (Expr.Fmt.pp_print_expr (snd cx, Ctx.dot)) (List (And, es) @@ h); *)
  			let es = List.flatten (map Smt.deconj es) in
        let ks = mapi (fun i e -> Fact (app_expr (shift i) e, Visible, tm) @@ h) es in
        let cx = Expr.Visit.adjs cx ks in
        let n = List.length ks - 1 in                                         (** [n] = number of new hypotheses; the 1 corresponds to [h] *)
        let hs = Dq.map (fun i h -> app_hyp (bumpn i (shift n)) h) hs in      (** apply [shift n] only to the ids that are higher than [i] *)
        cx, ks, hs
    | _ ->
        let cx = Expr.Visit.adj cx h in
        cx, [h], hs
  in
  let rec skol_hyps (cx,hs,c) =
(* Util.eprintf "[-]%d: %a" (Dq.size hs) Fu.pp_print_minimal (Fu.Big (fun ff -> ignore (Expr.Fmt.pp_print_sequent (hs, Ctx.dot) ff {context=hs;active=c}))); *)
    match Dq.front hs with
    | None ->
        (cx, Dq.empty, c)
    | Some (h, hs) ->
        let cx, ks, hs = skol cx h hs in
        let n = List.length ks - 1 in                                         (** [n] = number of new hypotheses; the 1 corresponds to [h] *)
        (* let ks = Dq.map (fun i h -> app_hyp (bumpn i (shift n)) h) ks in      (** apply [shift n] only to the ids that are higher than [i] *) *)
        (* let hs = Dq.map (fun i h -> app_hyp (bumpn i (shift n)) h) hs in      (** apply [shift n] only to the ids that are higher than [i] *) *)
        let c = app_expr (bumpn (Dq.size hs) (shift n)) c in
        let cx,hs,c = skol_hyps (cx,hs,c) in
(* Util.eprintf "       Goal:  %a" (Typ_e.pp_print_expr (snd cx, Ctx.dot)) c; *)
        let hs = Dq.append (Dq.of_list ks) hs in
(* let cx = Expr.Visit.adjs cx ks in *)
        (cx,hs,c)
  in
(* Util.eprintf "[original]:\n   @[<hov>%a@]" Fu.pp_print_minimal (Fu.Big (fun ff -> ignore (Expr.Fmt.pp_print_sequent (sq.context, Ctx.dot) ff sq))); *)
  let sq,nu = uncurry sq 0 in                                                 (** [nu] = number of uncurried ids from [sq.active] *)
(* Util.eprintf "[uncurried]:\n   @[<hov>%a@]" Fu.pp_print_minimal (Fu.Big (fun ff -> ignore (Expr.Fmt.pp_print_sequent (sq.context, Ctx.dot) ff sq))); *)
(* Util.eprintf "       Goal:  %a" (Typ_e.pp_print_expr (sq.context, Ctx.dot)) sq.active; *)
  let cx,hs,c = Smt.fix3 99 skol_hyps (((),sq.context), sq.context, sq.active) in
(* Util.eprintf "[skolemized]:\n   @[<hov>%a@]" Fu.pp_print_minimal (Fu.Big (fun ff -> ignore (Expr.Fmt.pp_print_sequent (hs, Ctx.dot) ff { context = hs ; active = c }))); *)
  { context = hs ; active = c }

let rec skolemize sq = Smt.fix_sq 99 skolemize_once sq

(****************************************************************************)

(** r_term ::=
      <Id/Opaque symbol> | r_term(r_term,..,r_term) | Prime (r_term)
      | FcnApp (r_term, _) *)
let rec is_rw_term1 e =
  match e.core with
  | Ix _ | Opaque _ -> true
  (* | Apply ({core = Internal B.Prime}, [ex]) -> is_rw_term1 ex *)
  | Apply (ex, es) -> for_all is_rw_term1 (ex :: es)
  | FcnApp (ex, _) -> is_rw_term1 ex    (** becareful: f[x] may not be present in the original formula, but it can result from an rewriting execution. *)
  | Dot (ex, _) -> is_rw_term1 ex
  | Internal B.Prime
  | Internal B.Len
  | Internal B.Append
  | Internal B.Cat
  | Internal B.SubSeq
      -> true
  | _ -> false
(** rew_domain ::= DOMAIN (r_term) *)
and is_rw_domain e =
  match e.core with
  | Apply ({core = Internal B.DOMAIN}, [ex]) -> is_rw_term1 ex
  | _ -> false

(** Is [x] a rewrite term? *)
let is_rw_term x =
  (is_rw_term1 x || is_rw_domain x)
  (* && not (mem (ix_id x) (free_vars cx y))  *)

(** terms [x] whose definitions [x = exp] remain in the PO *)
(* let is_persistent e =
  match e.core with
  | Apply ({core = Internal B.DOMAIN}, _)
  | FcnApp _    (** becareful!: f[x] may not be present in the original formula, but it can result from an rewriting execution. *)
  | Dot _
  | Apply ({core = Internal (B.Len | B.Append | B.Cat | B.SubSeq)}, _) ->
      true
  | _ ->
      false *)

let rec is_subexpr x y =
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.iter as super
    method expr scx e =
      if Expr.Eq.expr x e then raise Not_found else super#expr scx e
    method hyp scx h = match h.core with
      | Defn (_, _, Hidden, _)                                                (** ignore these cases *)
      | Fact (_, Hidden, _) -> Expr.Visit.adj scx h
      | _ -> super#hyp scx h
  end in
  begin try
    ignore (visitor#expr ((),Dq.empty) y) ; false
  with Not_found -> true end

(****************************************************************************)
(* Simplify top-level equalities                                            *)
(****************************************************************************)
let simpl_eq scx (hs,c) =
	(** Returns, if possible, a rewriting equality from expression [e] *)
  let rw_pair e =
    match e.core with
    | Apply ({core = Internal B.Eq}, [x ; y])
				when is_rw_term x && not (is_subexpr x y) ->
(* Util.eprintf "simpl: %a --> %a" (Typ_e.pp_print_expr (snd scx, Ctx.dot)) x (Typ_e.pp_print_expr (snd scx, Ctx.dot)) y; *)
        Some (x,y)
    | Apply ({core = Opaque "boolify"}, [ex]) ->
        Some (ex, Internal B.TRUE %% [])
    | _ -> None
  in
  (** Collect equalities *)
  let eqs hs = List.fold_left begin fun r e ->
      match rw_pair e with Some (x,y) -> (x,y) :: r | None -> r
    end [] hs
  in
	(** Apply rewriting rule [x --> y] in expression [e] *)
  let rw scx (x,y) e =
    let visitor = object (self : 'self)
      inherit [unit] Expr.Visit.map as super
      method expr scx' e =
        let n = (Dq.size (snd scx')) - (Dq.size (snd scx)) in
        let x = app_expr (shift n) x in
        let y = app_expr (shift n) y in
        if is_rw_term e && Expr.Eq.expr x e then
          y
        else
          super#expr scx' e
    end in
    visitor#expr scx e
  in
  let ff (hs,c) (x,y) =
    (** Apply rewriting rule [x --> y] to hypothesis [h] that does not match [x = _] and that not satisfy [is_persistent x]  *)
    (* let rw_hyp h =
      let c = match eqs [h] with
        | [x',_] when Expr.Eq.expr x x' && is_persistent x' -> false
        | _ -> true in
      if c then rw scx (x,y) h else h
    in *)
    (** Rewrite hypothesis [h] if it is not a rw expression *)
    let rw_hyp h =
      match rw_pair h with
      | Some (x',_) when not (Expr.Eq.expr x x') -> rw scx (x,y) h
      | Some _ -> h
      | None -> rw scx (x,y) h
    in
    map rw_hyp hs, rw scx (x,y) c
  in
  let rwr = (* rev *) (eqs hs) in
(* (iter (fun (x,y) -> Util.eprintf "rwr: %a --> %a" (Typ_e.pp_print_expr (snd scx, Ctx.dot)) x (Typ_e.pp_print_expr (snd scx, Ctx.dot)) y) rwr); *)
  let rwr = fold_left begin fun rs (x,y) -> 																	(** Apply substitutions [rwr] to itself *)
      (x,y) :: (map (fun (a,b) -> rw scx (x,y) a, rw scx (x,y) b) rs)
    end [] rwr
  in
(* (iter (fun (x,y) -> Util.eprintf "simpl: %a --> %a" (Typ_e.pp_print_expr (snd scx, Ctx.dot)) x (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) y) rwr); *)
  fold_left ff (hs,c) rwr																											(** Apply substitutions [rwr] to the proof obligation [hs,c] *)

(****************************************************************************)
(* From Batteries List                                                      *)
(****************************************************************************)
type 'a mut_list =  {
  hd: 'a;
  mutable tl: 'a list
}

external inj : 'a mut_list -> 'a list = "%identity"

let sort_unique cmp lst =
  let sorted = sort ~cmp:cmp lst in
  let fold first rest = fold_left
    (fun (acc, last) elem ->
       if (cmp last elem) = 0 then (acc, elem)
        else (elem::acc, elem)
    )
    ([first], first)
    rest
   in
  match sorted with
   | [] -> []
   | hd::tl ->
   begin
    let rev_result, _ = fold hd tl in
    rev rev_result
   end

let split_at index = function
  | [] -> if index = 0 then [],[] else invalid_arg "Index past end of list"
  | (h :: t as l) ->
    if index = 0 then [],l
    else if index < 0 then invalid_arg "Negative index not allowed"
    else
      let rec loop n dst l =
        if n = 0 then l else
        match l with
        | [] -> invalid_arg "Index past end of list"
        | h :: t ->
          let r = { hd =  h; tl = [] } in
          dst.tl <- inj r;
          loop (n-1) r t
      in
      let r = { hd = h; tl = [] } in
      inj r, loop (index-1) r t
(** End from Batteries List *************************************************)

(****************************************************************************)

(** An expression [e] is bounded iff
      [e]'s free variables are bounded by a quantifier,
      meaning that ... *)
let is_bounded scx e offset =
  let diff = (Dq.size scx - offset) in
(* Util.eprintf "___ is_bounded [%d-%d=%d] ex:%a" (Dq.size scx) offset diff (Expr.Fmt.pp_print_expr (scx, Ctx.dot)) e ; *)
  (** [Dq.size scx - offset] = number of quantifiers, ie number of extra variables in context [scx] *)
  let b = diff > 0 && Smt.free_n_vars diff [] e in
  (* Util.eprintf "... %s" (if b then "yes!" else "nope") ; *)
  b

(** [bs,vs] = nonbasic vars, not repeated, bounded and not-bounded by the context [scx] except the quantifiers [n_bs] *)
let bvars scx ex n_bs =
(* Util.eprintf "___ bvars [%d - %d] ex:%a" (Dq.size scx) n_bs (Expr.Fmt.pp_print_expr (scx, Ctx.dot)) ex ; *)
  (** List of non-basic variables occuring in [e] ([cx] is needed just by [Smt.map_list]) *)
  let rec nonbasic_vars cx e : string list =
    match e.core with
    | Opaque id -> if SMap.mem id !Smt.skolem1_ids then [id] else []
    | _ -> Smt.map_list nonbasic_vars cx e
  in
  (* nonbasic_vars (Smt.to_cx scx) ex *)
  nonbasic_vars [] ex                                                         (** Context [to_cx scx] not needed. *)
  (* |> fun ss -> (Util.eprintf "   = %s" (String.concat "," ss)) ; ss *)
  |> Smt.remove_repeated
  |> map (fun s -> let dd = SMap.find s !Smt.skolem1_ids in s,dd)
  |> partition
      begin fun (_,(scx',e,_)) ->
(* Util.eprintf "___ free_n_vars offset:%d ex:%a" (Dq.size cx - offset) (Expr.Fmt.pp_print_expr (Dq.empty, Ctx.dot)) e ;   (** [e] is opaqued! *) *)
        (* Smt.free_n_vars (Dq.size cx - offset) [] e *)
        is_bounded scx' e (Dq.size scx - n_bs)
      end

let mk_defs2 scx ss =
  map begin fun (id,(scx',e,b)) ->
    let d = Dq.size scx - Dq.size scx' in
    let e = if d > 0 then app_expr (shift d) e else e in
    let opq = Opaque id @@ e in
    let opq = if b then Property.assign opq Smt.boundvar () else opq in
    Apply (Internal B.Eq |> noprops, [ opq ; e ])
    |> noprops
  end ss

let dq_split_at n scx =
  (* Dq.fold_left begin
    fun (l,r) a -> if Dq.size l < n then Dq.cons a l,r else l,Dq.cons a r
  end (Dq.empty,Dq.empty) scx  *)
  split_at n (Dq.to_list scx)
  |>> Dq.of_list
  ||> Dq.of_list


let is_unspec e = match e.core with
  (* | Apply ({core = Opaque "tla__unspec"}, _) -> true *)
  | _ -> false

(** Is expression [e] non-basic?
    Range is considered basic, i.e. it can be axiomatized.
    *)
let is_nonbasic e =
  match e.core with
  | SetEnum [] -> false
  | Tuple [] -> false
  | Apply ({core = Internal (B.Cap | B.Cup | B.Setminus | B.SUBSET | B.UNION)}, _)
  | SetOf _ | SetSt _ | SetEnum (_ :: _)
  (* | Apply ({core = Internal B.Range}, _)  *)
  | Expr.T.Fcn _ | Arrow _ | Except _
  | Rect _ | Product _
  | Choose _
  | Record _
  | Tuple _
  (* | Apply ({core = Internal B.Len}, _)  *)
  (* | Apply ({core = Internal B.Len}, [{core = Apply ({core = Internal B.Tail}, _)}]) *)
  (* | Apply ({core = Internal B.Cat}, _) | Apply ({core = Internal B.SubSeq}, _)  *)
  | Lambda _ ->
      true
  | _ when is_unspec e -> true
  | If (_,t,u)
      when (!Smt.mode = Smt.Spass || !Smt.mode = Smt.Fof)
        && not (Typ_t.is_hard_bool t && Typ_t.is_hard_bool u) -> true
  | _ -> false

let find_nonbasic_op_id2 scx e offset =
  (* let e = opaque (to_cx scx) e in *)
(* Util.eprintf "___ find_nonbasic_op_id2 %a" (Expr.Fmt.pp_print_expr (scx, Ctx.dot)) e ; *)
  try let v,(_,_,b) = find
      begin fun (_,(scx',e',_)) ->
        (* let d = Dq.size scx - Dq.size scx' in
        let e = if d > 0 then app_expr (shift d) e else e in *)
(* Util.eprintf "   eq? %d/%d, %a -- %a" (Dq.size scx) (Dq.size scx') (Smt.print_prop ()) e (Smt.print_prop ()) e' ; *)
(* Util.eprintf "   [1] %a" (Expr.Fmt.pp_print_expr (scx, Ctx.dot)) e ; *)
(* Util.eprintf "   [2] %a" (Expr.Fmt.pp_print_expr (scx', Ctx.dot)) e' ; *)
        (* let e = Smt.opaque ~strong:true (Smt.to_cx scx) e in *)
        (* let e' = Smt.opaque ~strong:true (Smt.to_cx scx') e' in *)
(* Util.eprintf "   eq? %d/%d, %a -- %a" (Dq.size scx) (Dq.size scx') (Smt.print_prop ()) e (Smt.print_prop ()) e' ; *)
(* Util.eprintf "   [1'] %a" (Expr.Fmt.pp_print_expr (scx, Ctx.dot)) e ; *)
(* Util.eprintf "   [2'] %a" (Expr.Fmt.pp_print_expr (scx', Ctx.dot)) e' ; *)
        let r = Expr.Eq.expr e e' in
(* Util.eprintf "  -- %s --" (if r then "equal" else "[not-equal]") ; *)
        r
      (* Expr.Eq.expr (opaque ~strong:true cx e) (opaque ~strong:true cx' e') *)
      end (SMap.bindings !Smt.skolem1_ids)
    in
(* Util.eprintf "   old nonbasic id: %s" v ; *)
    v,b
  with Not_found -> begin
    let v = Smt.nonbasic_prefix ^ (fresh_id ()) in
    let b = is_bounded scx e offset in
    let v = Smt.turn_first_char b v in
(* Util.eprintf "   new nonbasic id: %s" v ; *)
    Smt.skolem1_ids := SMap.add v (scx,e,b) !Smt.skolem1_ids ;
    (* Smt.record_signatures := (Option.default [] (rec_sign e)) :: !Smt.record_signatures; *)
    v,b
  end

let add_hyps hs ex =
  let hs',ex = Smt.deimpl ex in
  let imp x y = Apply (Internal B.Implies |> noprops, [x ; y]) |> noprops (* @@ ex *) in
  match hs @ hs' with
  | [] -> ex
  | [h] -> imp h ex
  | hs -> imp (List (And, hs) |> noprops) ex

let add_eqs ss scx ex =
  (* let ss = filter (fun (_,(_,_,b)) -> not b) ss in *)
  if ss = [] then ex else
  let bs' = List.map (fun (id,(_,e,_)) -> ((* Smt.turn_first_char true *) id) @@ e, Unknown, No_domain) ss in
  let ex = add_hyps (mk_defs2 scx ss) ex
    |> app_expr (shift (length bs'))
  in
  Quant (Forall, bs', ex) @@ ex

(** TODO: abstract (and normalize) just one non-basic expression at a time (with all its occurences, of course)
    See, for instance, the translation of, with two non-basic expressions:
LEMMA
  ASSUME NEW h(_)
  PROVE  [a |-> h(1), b |-> h(2)]  =
         [x \in {"a","b"} |-> IF x = "a" THEN h(1) ELSE h(2)]
  BY TPTP   \** function extensionality missing
*)
let abstract scx (hs,c) =
  let offset1 = Dq.size (snd scx) in

  (** Record top-level abstracted variables in [Smt.skolem1_ids].
      Insert quantified abstracted variables in the sequent. *)
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.map as super
    method expr scx e = match e.core with
    | Quant (q, bs, ex) ->
(* Util.eprintf "___ abstract %a" (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e ; *)
        let scx',bs = self#bounds scx bs in
        let ex = self#expr scx' ex in
        let n_bs = length bs in

        (** Find the set of basic expressions�in [ex], given that there are [m]=[Dq.size (snd scx)] hyps in the context:
              [ss] = bounded by [bs]
              [nss] = not bounded by [bs] *)
        let ss,nss = bvars (snd scx') ex n_bs in

(* iteri (fun i (id,(scx',e,b)) -> Util.eprintf "ss[%d] = %s -> %a " i id (Expr.Fmt.pp_print_expr (scx', Ctx.dot)) e) ss ; *)
(* iteri (fun i (id,(scx',e,b)) -> Util.eprintf "nss[%d] = %s -> %a " i id (Expr.Fmt.pp_print_expr (scx', Ctx.dot)) e) nss ; *)

        (** (Un)shift [nss] by the number of quantified variables [n] *)
        iter begin fun (id,(scx',e',b)) ->
          let _,scx' = dq_split_at n_bs scx' in
          let e' = app_expr (shift (0 - n_bs)) e' in
          Smt.skolem1_ids := SMap.add id (scx',e',b) !Smt.skolem1_ids
          end nss ;

        (** Add the definitions of [ss] to [ex] *)
        let ex = add_eqs ss (snd scx') ex in

        (** Remove recorded [ss] *)
        iter (fun (v,_) -> Smt.skolem1_ids := SMap.remove v !Smt.skolem1_ids) ss ;

        Quant (q, bs, ex) @@ e

    | _ when is_nonbasic e ->
(* Util.eprintf "___ nonbasic found: %a" (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e ; *)
        let id,b = find_nonbasic_op_id2 (snd scx) e offset1 in
        let e = Opaque id @@ e in
        (if b then Property.assign e Smt.boundvar () else e)
    | _ ->
        super#expr scx e
  end in
(* Util.eprintf "abstract [0] "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)

  let hs,c = map (visitor#expr scx) hs, visitor#expr scx c in
(* Util.eprintf "abstract [1] "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)

  (** Insert the list of hypotheses [ss] at the beginning of the list of hyps [hs] *)
  (* find position in [sq.context] where Fresh or Fact Visible occurs *)
  let insert_hyps ss hs =

(* iteri (fun i (id,(scx',e)) ->
  (* let e = app_expr (shift i) e in *)
  Util.eprintf "ss[%d] = %s -> %a // %a" i id   (Expr.Fmt.pp_print_expr (scx', Ctx.dot)) e   (print_prop ()) e
  ) ss ; *)

    let ss = filter (fun (_,(_,_,b)) -> not b) ss in
    let mk_defs2 scx ss = mapi
      begin fun i (id,(scx',e,b)) ->
        (* let e = app_expr (shift i) e in *)
        (* let e = opaque (to_cx scx') e in *)
        (* let d = Dq.size scx - Dq.size scx' in *)
        (* let e = if d > 0 then app_expr (shift d) e else e in *)
        Apply (Internal B.Eq |> noprops, [ Opaque id @@ e ; (* opaque (to_cx scx') *) e ]) %% []
      end ss
    in
    let eqs = mk_defs2 scx ss in
    iter (fun (id,(scx,e,_)) -> Smt.skolem1_ids := SMap.add id (scx,e,true) !Smt.skolem1_ids) ss ;
(* iteri (fun i e -> Util.eprintf "eqs[%d] = %a" i (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e) eqs ; *)
    eqs @ hs
  in

  let hs = insert_hyps (SMap.bindings !Smt.skolem1_ids) hs in
(* Util.eprintf "abstract [9] "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Expr.Fmt.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)
  hs,c


(****************************************************************************)
(* Abstract non-basic expressions (version 2)                               *)
(****************************************************************************)
(* Kinds of non-basic expressions E:
   - P(E)              non-shifted, no free variables
   - \A x : P(E,x)     shifted, e.g. by quantified variables, no free variables
   - \A x : P(E(x),x)  shifted, with free variables [x] bound by \A x       *)
(****************************************************************************)

let abstract2 scx (hs,c) =
(* Util.eprintf "abstract "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)
  (* let Smt.skolem2_ids = ref SMap.empty in *)
  let offset0 = Dq.size (snd scx) in
  let fvis off e =
(* Util.eprintf "      fvis/%d-%d %a" off offset0 (Expr.Fmt.pp_print_expr (Dq.empty, Ctx.dot)) e ; *)
    Smt.fv_expr_i 0 e
    (* |> fun xs -> Util.eprintf "      :: %s" (String.concat "," (map string_of_int xs)) ; xs *)
    |> Smt.remove_repeated
    |> List.filter (fun i -> i <= off)
    |> List.sort in                                                           (** Becareful: [remove_repeated] changes original order *)

  (** Canonical form of an expression [e] = e[xs <- fvi(e)]
      where xs = [1,2,...,n] and n = length (fvi(e))
      (That is, the expression [e] at [offset0], ie the top-level context [scx].)
      Example:
        e   = {Ix 3, Ix 1, Ix 4, Ix 1, Ix 5}
        fvs = [1;3;4;5]
        is  = [1;2;2;3;4]  <-- new indices replacing [1;2;3;4;5]
        e[is <- fvs] = e[Ix 1 <- 1][Ix 2 <- 2][Ix 2 <- 3][Ix 3 <- 4][Ix 4 <- 5]
                     = e[Ix 1 <- 1][Ix 2 <- 2][Ix 2 <- 3][Ix 3 <- 4][Ix 4 <- 5]
                     = {Ix 2, Ix 1, Ix 3, Ix 1, Ix 4}

        Generate new indices [gen_indices]:
        1 [1;3;5]  -> [1]       (present)
        2 [3;5]    -> [1;2]     (absent)
        2 [2;4]    -> [1;2;2]   (present)
        3 [4]      -> [1;2;2;3] (absent)
        3 [3]      -> [1;2;2;3;3] (present)

        1 [2,3]
        1 [1,2]
        2 [2] *)
  let canonical offset e =
(* Smt.ifprint 2 "^^ canonical (%d) of %a" offset (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) e ; *)
    (* let e = app_expr (shift (-offset)) e in *)
(* Util.eprintf "^^ canonical (%d-%d) of %a" offset offset0 (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e ; *)
    let fvs = fvis offset e in
(* - P(E)               canonical E = E
   - \A x : P(E,x)      canonical E = shift -length(x) E
   - \A x : P(E(x),x)   canonical E(x) = old_canonical(E(x))      // E will be always bound, so no need to shift
   *)
    if fvs = [] then app_expr (shift (-offset)) e else begin
(* Smt.ifprint 2 "   fvs [%s]" (String.concat "," (map string_of_int fvs)) ; *)
      let rec gen_indices n = function
        | x :: xs when x = n -> n :: gen_indices (n+1) xs
        | x :: xs ->
            let dec xs = map (fun x -> x - 1) xs in
            n :: gen_indices n (dec (x::xs))
        | [] -> []
      in
      let is = gen_indices 1 fvs in
(* Smt.ifprint 2 "   indices [%s]" (String.concat "," (map string_of_int is)) ; *)
      let ss = List.fold_left begin fun r x ->
        scons (Ix x %% []) r
        end (shift (List.length is)) (List.rev is)
      in
(* Smt.ifprint 2 "vv result %a" (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) (app_expr ss e) ; *)
      app_expr ss e
    end
  in

  (** Assumes [e] is in canonical form *)
  let find_nonbasic_op offset e =
    let e = canonical offset e in
(* Util.eprintf "___ find_nonbasic_op \\@ %d :: %a" offset (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) e ; *)
(* Util.eprintf "___ find_nonbasic_op %a" (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e ; *)
    try let v,_ = List.find
        begin fun (_,(e',off',_)) ->
          (* let e = app_expr (shift (off' - offset)) e in     (** [canonical] was made in part to _not_ do this! *) *)
          (* let e' = canonical offset e' in *)
          let b = Expr.Eq.expr e e' in
(* Util.eprintf "   ** %sequal with [%d/%d] %a" (if b then "" else "not ") offset off' (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) e'; *)
          b
        end (SMap.bindings !Smt.skolem2_ids)
      in
      v
    with Not_found -> begin
      let v = Smt.nonbasic_prefix ^ (fresh_id ()) in
      let v = if is_unspec e then v^"__unspec" else v in
      Smt.skolem2_ids := SMap.add v (e,offset,false) !Smt.skolem2_ids ;          (** offset = 0 *)
      v
    end
  in

  (** Returns abstract operator [k] for non-basic expression [e],
        with the same free variables.
      Example:
        e   = {Ix 3, Ix 1, Ix 4, Ix 1, Ix 3}
        offset = 2
        fvs = [3;4]     (non-repeated, does not matter the order)
        abstract_op e = k(Ix 3, Ix 4)
      *)
  let abstract_op offset e =
    let fvs = fvis offset e in
(* Util.eprintf "___ abstract_op %d %a [%s]" offset (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) e (String.concat "," (map string_of_int fvs)); *)
(* Util.eprintf "___ abstract_op %d %a" offset (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e ; *)
    let args = map (fun v -> Ix v %% []) fvs in
    let k = find_nonbasic_op offset e in
    match length args with
    | 0 -> Opaque k @@ e
    | _ -> Apply (Opaque k %% [], args) @@ e
  in

  (** Visit an expression [e]:
      1. Recording in [Smt.skolem2_ids] every non-basic sub-expression [\psi] in canonical form.
      2. Replacing [\psi] by [k(fvs)], where FV(\psi) = fvs and [k] is fresh.
    *)
  let visitor = object (self : 'self)
    inherit [unit] Expr.Visit.map as super
    method expr scx e =
(* Util.eprintf "%d:: %a" (Dq.size (snd scx) - offset0) (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e ; *)
      if is_nonbasic e
      then abstract_op (Dq.size (snd scx) - offset0) e
      else super#expr scx e
  end in
  let hs,c = map (visitor#expr scx) hs, visitor#expr scx c in
(* Util.eprintf "abstract [1] "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)

(* Util.eprintf "---------------------------" ; *)
  let mk_defs ops =
    let ops = filter (fun (_,(e,_,defined)) -> not (is_unspec e) && not defined) ops in
    map begin fun (k,(e,off,_)) ->
      let fvs = fvis off e in
(* Util.eprintf "  mk_def  %s : %a  [%s]" k (Typ_e.pp_print_expr (Dq.empty, Ctx.dot)) e  (String.concat "," (map string_of_int fvs)) ; *)
      let bs = map begin fun v ->
          ("x"^(string_of_int v)) %% [], Constant, No_domain
        end fvs
      in
      (* let e = canonical off e in *)
      let k = abstract_op off e in
      let ex = Apply (Internal B.Eq %% [], [ k ; e ]) %% [ ] in
      (* let ex = Property.assign ex Smt.pattern_prop "(blah)" in *)
      match k.core with
      | Apply _ -> Quant (Forall, bs, ex) %% []
      | _ -> ex
    end ops
  in
  let defs = mk_defs (SMap.bindings !Smt.skolem2_ids) in
(* Util.eprintf "abstract defs: "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e) defs ; *)
  let hs = defs @ hs in
  (* let hs = hs @ defs in *)
  Smt.skolem2_ids := SMap.mapi (fun _ (e,o,_) -> e,o,true) !Smt.skolem2_ids; (** mark all as already defined by [mk_defs] *)

(* Util.eprintf "abstract "; List.iteri (fun i e -> Util.eprintf "  #[%d] = %a" i (Typ_e.pp_print_expr (snd scx, Ctx.dot)) e) (hs @ [c]) ; *)
  hs, c
