(*
 * module/elab.ml --- modules (elaboration)
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Format
open Fmtutil
open Tla_parser
open Property
open Util.Coll
open Util

open Expr.T
open Expr.Subst
open Proof.T

open M_t

(*let debug = Printf.eprintf;;*)

(******************************************************************************)

let localize_axioms body =
  let rec spin prefix = function
    | [] -> List.rev prefix
    | mu :: mus ->
        begin match mu.core with
        | Axiom (nm, e) ->
            let (prefix, e) =
                (* [NOTE] e is shifted by 1 and moved into mus, then
                 * mus is shifted by -1 before spinning *)
              match nm with
              | None ->
                  (prefix, app_expr (shift 1) e)
              | Some nm ->
                  ((Definition
                      (Operator (nm, e) @@ mu, Proof Always, Visible, Export)
                    @@ mu)
                   :: prefix,
                   Ix 2 @@ mu)
            in
            let h = Fact (e, Visible, Always) @@ mu in
            let rec insert_ax rinits n = function
              | [] -> List.rev rinits
              | mu :: mus ->
                  begin match mu.core with
                  | Theorem (nm, sq, naxs, prf,prf_orig, summ) ->
                      let h = app_hyp (shift n) h in
                      let sq = app_sequent (shift 1) sq in
                      let sq = { sq with context = Deque.cons h sq.context } in
                      let mu =
                        Theorem (nm, sq, naxs + 1, prf, prf_orig, summ) @@ mu
                      in
                      insert_ax (mu :: rinits)
                                (if nm = None then n + 1 else n + 2)
                                mus
                  | _ ->
                      insert_ax (mu :: rinits) (n + hyp_size mu) mus
                end
            in
            let mus = insert_ax [] 0 mus in
            let (_, mus) = M_subst.app_modunits (shift (-1)) mus in
            spin prefix mus
        | _ ->
            spin (mu :: prefix) mus
        end
  in
  spin [] body

(******************************************************************************)

let salt_counter = ref 0;;
let salt oname =
  incr salt_counter;
  (oname.core ^ "$" ^ string_of_int !salt_counter) @@ oname


module StringMap = Util.Coll.Sm  (* Map.Make(String) *)
module StringSet = Util.Coll.Ss  (* Set.Make(String) *)

open Util

module HC = struct
  type t = hint
  let compare x y = Stdlib.compare x.core y.core
end

module HintMap = Util.Coll.Hm  (* Map.Make(HC) *)
module HintSet = Util.Coll.Hs  (* Set.Make(HC) *)


let module_parameters (tla_module: M_t.mule):
        StringSet.t =
    (* Return a `StringSet` containing the `VARIABLE` and `CONSTANT`
    identifiers declared in module scope in the module `tla_module`.
    *)
    let rec scan params = function
        | [] -> params
        | module_unit :: module_units ->
            let params = begin match module_unit.core with
                | Constants constants ->
                    let f = fun params (name, _) ->
                                StringSet.add name.core params in
                    List.fold_left f params constants
                | Variables variables ->
                    let f = fun params name ->
                                StringSet.add name.core params in
                    List.fold_left f params variables
                | _ -> params
            end in
            scan params module_units in
      scan StringSet.empty tla_module.core.body


let find_instantiated_module
        (instance: Expr.T.instance wrapped)
        (mcx: M_t.modctx):
            M_t.mule =
    let module_name = instance.core.inst_mod in
    let found_module = StringMap.mem module_name mcx in
    if not found_module then begin
        Errors.err ~at:instance
            "Module %S not found"
            module_name;
        failwith "Module.Elab.is_instance_of_module"
    end else
        let tla_module = StringMap.find module_name mcx in
        tla_module


let instance_substitution_to_map
        (instance: Expr.T.instance wrapped) =
    (* Roll given substitution into a map for efficient lookup *)
    let (instance_substitution: (hint * Expr.T.expr) list) =
        instance.core.inst_sub in
    let f = fun subst (var, expr) -> HintMap.add var expr subst in
    let substitution_map =
        List.fold_left f HintMap.empty instance_substitution in
    substitution_map


let assert_instance_substitutes_declared_identifiers
        substitution_map
        module_parameters
        (module_name: string):
            unit =
    (* Raise error if any instantiated parameter is not declared in the
    instantiated module.
    *)
    let check (op: hint) _ =
        if not (StringSet.mem op.core module_parameters) then begin
            Errors.err ~at:op "%s" (
                "Parameter " ^ op.core ^ " occurs in the statement " ^
                "`INSTANCE " ^ module_name ^ " WITH`, " ^
                "and is not declared in the module " ^ module_name ^ "\n");
            failwith "Module.Elab.instance_substitutes_declared_identifiers"
        end
        in
    HintMap.iter check substitution_map


let extend_context
        (cx: Expr.T.ctx)
        (instance_args: hint list):
            Expr.T.ctx =
    (* Extend the context `cx` with the parameters that occur in the
    `WITH` of the statement `INSTANCE ModuleName WITH ...`.

    The parameters are declared as `CONSTANTS` of arity _ ,
    in module scope.
    *)
    let extend cx v =
        let fresh_op = Fresh (v, Shape_expr, Unknown, Unbounded) in
        let decl = fresh_op @@ v in
        Deque.snoc cx decl  (* append to module context *)
    in
    List.fold_left extend cx instance_args


let complete_with_statement_params
        inst
        substitution_map
        (module_parameters: StringSet.t)
        cx
            =
    (* Complete the substitution with the missing parameters *)
    let f s subst =
        if HintMap.mem (s @@ inst) subst then
            subst
        else
            match Deque.find cx (Expr.Anon.hyp_is_named s) with
            | None ->
                Errors.err ~at:inst "%s" (
                    "Required parameter " ^ s ^ " for module " ^
                    inst.core.inst_mod ^ " could not be inferred.\n");
                failwith "Module.Elab.complete_with_statement_params"
            | Some _ ->
            HintMap.add (s @@ inst) (Opaque s @@ inst) subst
    in
    StringSet.fold f module_parameters substitution_map


let anonymize_substitution anon cx subst =
    HintMap.map (anon#expr ([], cx)) subst


let remove_pf mu =
    (* Erase proofs from module `mu`. *)
    match mu.core with
    | Theorem (nm, sq, naxs, prf, prf_orig, summ) ->
        Theorem (nm, sq, naxs, (Omitted Implicit @@ prf), prf_orig, summ) @@ mu
    | _ -> mu


let lambdify_expr cx expr =
    (* Both `ENABLED` and `\cdot` need to be lambdified for
    soundly performing module instantiation.
    So pass `true` for those options.
    *)
    let lambdify_enabled = true in
    let lambdify_cdot = true in
    let autouse = true in
    let expr = Expr.Action.lambdify cx expr
            ~lambdify_enabled:lambdify_enabled
            ~lambdify_cdot:lambdify_cdot
            ~autouse:autouse in
        expr


let lambdify_definition cx df =
    let expr = match df.core with
        | Operator (_, expr) -> expr
        | Bpragma (_, expr, _) -> expr
        | _ -> assert false in
    let expr = match expr.core with
        | Lambda _  (* arity < _, ... > *)
        | _ ->  (* arity _ *)
            let expr = lambdify_expr cx expr in
            Expr.Levels.rm_expr_level cx expr
        in
    let core = match df.core with
        | Operator (name, _) -> Operator (name, expr)
        | Bpragma (name, _, backend_args) -> Bpragma (name, expr, backend_args)
        | _ -> assert false in
    let df = core @@ df in
    Expr.Levels.rm_level df


let get_sequent expr = match expr.core with
    | Sequent sq -> sq
    | _ -> assert false


let lambdify_sequent cx (sq: Expr.T.sequent) =
    let sq_expr = noprops (Sequent sq) in
    let expr = lambdify_expr cx sq_expr in
    let expr = Expr.Levels.rm_expr_level cx expr in
    get_sequent expr


let lambdify_enabled_cdot cx mus =
    (* Lambdify `ENABLED` and `\cdot` in theorems and definitions. *)
    let visitor = object (self: 'self)
        inherit M_visit.map as super

        method definition cx df wd visibility e =
            let df = lambdify_definition cx df in
            super#definition cx df wd visibility e

        method theorem cx name sq naxs prf prf_orig summ =
            (* Lambdify `ENABLED` and `\cdot` to ensure
            soundness of instantiation, and of wrapping within
            defined operators.
            *)
            let sq = begin
                try
                    lambdify_sequent cx sq
                with Failure msg ->
                    let msg = (msg ^
                        "\nCould not instantiate the theorem " ^ (
                        match name with
                        | Some s ->
                            "named: " ^ s.core ^ ", "
                        | None -> ""
                        ) ^ "at: " ^ (Expr.T.format_locus sq.active)) in
                    Util.printf ~at:sq.active ~prefix:"[ERROR]" "%s" msg;
                    Backend.Toolbox.print_message msg;
                    {context=Deque.empty; active=(Internal TRUE) @@ sq.active}
                end in
            (* Proofs are not instantiated, so mappings relevant to
            `ENABLED` and `\cdot` are not applied within proofs.
            *)
            super#theorem cx name sq naxs prf prf_orig summ
    end
    in
    let (cx, mus) = visitor#module_units cx mus in
    mus


let rec apply_subst body body_len subst = function
    (* Perform the substitution. *)
    | [] -> List.rev body
    | mu :: mus -> begin match mu.core with
        | Constants [nm, _]
        | Variables [nm] ->
            let e = HintMap.find nm subst in
            let e = app_expr (shift body_len) e in
            let (_, mus) = M_subst.app_modunits (scons e (shift 0)) mus in
            apply_subst body body_len subst mus
        | Constants (c :: cs) ->
            apply_subst body body_len subst (
                (Constants [c] @@ mu)
                    :: (Constants cs @@ mu)
                    :: mus)
        | Variables (v :: vs) ->
            apply_subst body body_len subst (
                (Variables [v] @@ mu)
                    :: (Variables vs @@ mu)
                    :: mus)
        | _ ->
            apply_subst (mu :: body) (body_len + hyp_size mu) subst mus
        end


let tweak iname nm =
    (* Name tweaking. *)
    match iname.core with
    | "" -> nm
    | _ -> (iname.core ^ "!" ^ nm.core) @@ nm


let resub_for n niargs iargs inst =
    (* Tweaking substitution. *)
    (* This function is inefficient because it builds intermediate lists
     * and then iterates over them. It has a conceptual simplicity,
     * but if/when performance becomes an issue, this should be revisited.
     * Performance will degrade linearly with the product of the number
     * of INSTANCEs and the (maximum) size of the instancees
     *
     * This function builds a substitution to be applied to the nth unit
     * occurring in the body of the instancee.
     *
     * Step 1. all non-params (indexes outside 1 .. n + niargs) are unchanged
     *)
    let sub = shift (n + niargs) in
    (* Step 2. instance parameters, which were bound before in cx, are changed
     *         to be bound locally in the defn. Thus, the tail of the subst
     *         (indexes in range n + 1 .. n + niargs) are moved to 1 .. niargs.
     *)
    let sub =
        List.fold_right
            scons
            (List.init niargs (fun k -> Ix (k + 1) @@ inst))
            sub
        in
    (* Step 3. original parameters are now shifted up by niargs to account
     *         for the now localized instance parameters.
     *)
    let sub =
        let l =
            let init k =
                let op = Ix (k + niargs + 1) @@ inst in
                (if (List.length iargs) >= 1 then begin
                    assert ((List.length iargs) >= 1);
                    Apply (op, iargs) @@ inst end
                else begin
                    assert ((List.length iargs) = 0);
                    op end)
                in
            List.init n init
        in
        List.fold_right scons l sub
    in
    sub


let lambdify e inst niargs =
    (* Add additional lambdas if needed. *)
    Expr.Levels.rm_level begin match e.core with
    | Lambda (vs, le) ->
        let ivs = List.map
                    (fun v -> (v, Shape_expr))
                    inst.core.inst_args in
        Lambda (ivs @ vs, le) @@ e
    | _ ->
        if niargs = 0 then
            e
        else begin
            let ivs = List.map
                        (fun v -> (v, Shape_expr))
                        inst.core.inst_args in
            Lambda (ivs, e) @@ e
        end
    end


let rec localize body body_len iname niargs iargs not_complained inst local =
    function
    (* For each definition and fact, resub and lambdify. *)
  | [] -> List.rev body
  | mu :: mus ->
      begin match mu.core with
      | Definition ({core = Operator (nm, e)} as df, wd, vis, ex) ->
          let nm = if ex = Local then salt nm else nm in
          let nm = tweak iname nm in
          let e = app_expr (resub_for body_len niargs iargs inst) e in
          let e = lambdify e inst niargs in
          let wd = if ex = Local then Builtin else wd in
          let ex = if ex = Local then Local else local in
          let mu = Definition (Operator (nm, e) @@ df, wd, vis, ex) @@ mu in
          localize (mu :: body) (body_len + 1) iname niargs iargs
            not_complained inst local mus
      | Definition ({core = Bpragma (nm, e, meth)} as df, wd, vis, ex) ->
          (* This case is almost excaclty a duplicate of the previous one *)
          let nm = if ex = Local then salt nm else nm in
          let nm = tweak iname nm in
          let e = app_expr (resub_for body_len niargs iargs inst) e in
          let e = lambdify e inst niargs in
          let wd = if ex = Local then Builtin else wd in
          let ex = if ex = Local then Local else local in
          let mu =
            Definition (Bpragma (nm, e, meth) @@ df, wd, vis, ex) @@ mu
          in
          localize (mu :: body) (body_len + 1) iname niargs iargs
            not_complained inst local mus
      | Axiom (nm, e) ->
          let nm = Option.map (tweak iname) nm in
          let e = app_expr (resub_for body_len niargs iargs inst) e in
          if niargs > 0 && !not_complained then begin
            Errors.warn ~at:inst
              "%s\n%s@\n(%s)"
              "Instancing produces parametric axioms."
              "Such axioms will be forcibly hidden and cannot be cited."
              "This warning appears at-most once per INSTANCE declaration.";
            not_complained := false;
          end;
          let e = lambdify e inst niargs in
          let mu = Axiom (nm, e) @@ mu in
          localize (mu :: body) (body_len + hyp_size mu) iname niargs iargs
            not_complained inst local mus
      | Theorem (nm, sq, naxs, prf, prf_orig, summ) ->
          let nm = Option.map (tweak iname) nm in
          let e = exprify_sequent sq @@ mu in
          let e = app_expr (resub_for body_len niargs iargs inst) e in
          if niargs > 0 && !not_complained then begin
            Util.eprintf ~at:inst ~prefix:"Warning: "
              "%s@\n%s@\n(%s)"
              "Instancing produces parametric theorems."
              "Such theorems will be forcibly hidden and cannot be cited."
              "This warning appears at-most once per INSTANCE declaration.";
            not_complained := false;
          end;
          let e = lambdify e inst niargs in
          let sq =
            match e.core with
            | Sequent sq -> sq
            | _ -> {context = Deque.empty ; active = e}
          in
          let prf = Omitted (Elsewhere (Util.get_locus mu)) @@ mu in
          let mu = Theorem (nm, sq, naxs, prf, prf_orig, summ) @@ mu in
          localize (mu :: body) (body_len + 1) iname niargs iargs
            not_complained inst local mus
      | Mutate (`Hide, _) ->
          localize body body_len iname niargs iargs not_complained inst local
            mus
      | Mutate (`Use _, us) ->
          let (_, mus) =
            M_subst.app_modunits (shift (- (List.length us.Proof.T.facts))) mus
          in
          localize body body_len iname niargs iargs not_complained inst local
            mus
      | Submod _ ->
          localize body body_len iname niargs iargs not_complained inst local
            mus
      | Constants _
      | Recursives _
      | Variables _
      | Definition _
      | Anoninst _ ->
          (* the instancee has been normalized before, so there
           * should not be any parameters or (unnamed) instances. *)
          Errors.bug ~at:inst "Module.Elab.localize"
    end


(* The following function appears complex, but is actually pretty
 * straightforward. Do not be awed by its length, but instead try to
 * understand it piece by piece. *)

let instantiate
        anon
        (mcx: M_t.modctx)
        cx
        (instance: Expr.T.instance wrapped)
        ~local
        ~iname =
    let tla_module = find_instantiated_module instance mcx in
        let module_name = instance.core.inst_mod in
        (* let mule = tla_module in *)
        let inst = instance in
    (* compute the substitution *)
    let module_parameters = module_parameters tla_module in
        (* let mule_params = module_parameters in *)
    let substitution_map = instance_substitution_to_map instance in
        (* let subst = substitution_map in *)
    assert_instance_substitutes_declared_identifiers
        substitution_map
        module_parameters
        module_name;
    let cx = extend_context cx inst.core.inst_args in
    let subst = complete_with_statement_params
                    instance substitution_map
                    module_parameters cx in
    let subst = anonymize_substitution anon cx subst in
    (* bring mule body to here *)
    let cx_shift = Deque.size cx - tla_module.core.defdepth in
    assert (cx_shift >= 0);
    let body = tla_module.core.body in


    let body = List.map remove_pf body in
    let (_, body) = M_subst.app_modunits (shift cx_shift) body in
    (* lambdify `ENABLED` and `\cdot` *)
    let body = lambdify_enabled_cdot cx body in
    (* apply the substitution *)
    let body = apply_subst [] 0 subst body in
    let niargs = List.length inst.core.inst_args in
    let iargs = List.init niargs (fun k -> Ix (niargs - k) @@ inst) in
    let not_complained = ref true in
    let body = localize [] 0 iname niargs iargs not_complained inst local body
    in
    localize_axioms body


(******************************************************************************)
(* Anonymization (replacement of named variables and constants by
de Bruijn indices).
*)

let anon = object (self : 'self)
  inherit Proof.Anon.anon as super

  val mutable __mcx : modctx = StringMap.empty

  method mexpr mcx scx e =
    __mcx <- mcx ;
    self#expr scx e

  method mproof mcx scx prf =
    __mcx <- mcx ;
    self#proof scx prf

  method musable mcx scx us =
    __mcx <- mcx ;
    self#usable scx us

  method mhyp mcx scx hyp =
    __mcx <- mcx ;
    self#hyp scx hyp

  method msequent mcx scx sq =
    __mcx <- mcx ;
    self#sequent scx sq

  method defns scx dfs =
    match dfs with
    | {core = Instance (nm, inst)} as df :: dfs ->
        if not (StringMap.mem inst.inst_mod __mcx) then begin
          Errors.err ~at:df "Module %S unknown\n%!" inst.inst_mod;
          failwith "Module.Elab.anon#defns"
        end;
        let submus =
          instantiate self __mcx (snd scx) (inst @@ df) ~local:Local ~iname:nm
        in
        let rec make_defs sofar = function
          | [] -> List.rev sofar
          | mu :: mus ->
              begin match mu.core with
              | Definition (df, _, _, _) -> make_defs (df :: sofar) mus
              | Constants _
              | Recursives _
              | Variables _
              | Axiom _
              | Theorem _
              | Submod _
              | Mutate _
              | Anoninst _ ->
                let mu_hyps = M_t.hyps_of_modunit mu in
                let n_hyps = List.length mu_hyps in
                let (_, mus) = M_subst.app_modunits (shift (-n_hyps)) mus in
                make_defs sofar mus
              end
        in
        self#defns scx (make_defs [] submus @ dfs)
    | _ ->
        super#defns scx dfs
end

(******************************************************************************)

(* from `Proof.Gen` *)
let set_defn vis l df =
  let rec doit n l = match n with
    | 0 -> begin
        match Deque.front l with
          | Some ({core = Defn (d, wd, _, ex)} as h, l) -> Deque.cons (Defn (d, wd, vis, ex) @@ h) l
          | Some (e, _) ->
              if !Params.verbose then
                Util.eprintf ~at:df "Indicated point is not a definition, but %t!\n%!"
                  (fun ff -> ignore (Expr.Fmt.pp_print_hyp (l, Ctx.dot) ff e)) ;
              failwith "Proof.Gen.set_defn/doit" ;
          | None -> l
      end
    | n -> begin match Deque.front l with
        | Some (h, l) -> Deque.cons h (doit (n - 1) l)
        | _ -> Errors.bug ~at:df "set_defn for empty context"
      end
  in
    doit
      (match df.core with
            | Dx n -> Deque.size l - n
            | Dvar v ->
                if !Params.verbose then
                  Util.eprintf ~at:df "Unknown definition %S\n" v ;
                failwith "Proof.Gen.set_defn")
      l

(* from `Proof.Gen` *)
let domain_match f hran = match f.core with
  | Apply ({core = Internal Builtin.Mem}, [{core = Ix 0} ; ran])
      when Expr.Eq.expr hran ran ->
      true
  | _ -> false

(* from `Proof.Gen` *)
let set_expr vis f cx =
  let succ = ref false in
  let rec doit f hs = match Deque.front hs with
    | None -> Deque.empty
    | Some (h, hs) ->
        let f = app_expr (shift (-1)) f in
        let h = begin match h.core with
          | Fact (hf, hv, tm) when Expr.Eq.expr hf f ->
              succ := true ;
              Fact (hf, vis, tm)
          | Fresh (hx, shp, hk, Bounded (hran, hv)) when domain_match f hran ->
              succ := true ;
              Fresh (hx, shp, hk, Bounded (hran, vis))
          | h -> h
        end @@ h
        in Deque.cons h (doit f hs)
  in
  let cx = Deque.rev (doit f (Deque.rev cx)) in
    if !succ then cx else begin
      Util.eprintf ~at:f "This expression does not appear in the context and cannot be hidden.\n" ;
      failwith "proof.Gen.set_expr"
    end


let check_enabled_axioms_map = object (self: 'self)
    inherit [int ref * (Proof.T.step * hyp Deque.dq * int) StringMap.t]
        Proof.Visit.map as super

    method proof scx pf = let pf = match pf.core with
      | Omitted _ | Error _ -> pf
      | Obvious ->
          self#check_usable pf scx {facts=[]; defs=[]} false
      | By (usable, onl) ->
          let pf = By (self#usable scx usable, onl) @@ pf in
          self#check_usable pf scx usable onl
      | Steps (inits, qed) ->
          let (scx, inits) = self#steps scx inits in
          let qed_prf = self#proof scx (get_qed_proof qed) in
          Steps (inits, {qed with core = Qed qed_prf}) @@ pf
      in
      pf

    method step (((level, sm), cx) as scx) st =
        (*
        let step_str = Proof.Fmt.string_of_step cx st in
        print_string step_str;
        print_string "\n";
        *)
        let stepnm = string_of_stepno (Property.get st Props.step) in
        (* print_string stepnm; *)
        assert ((not (StringMap.mem stepnm sm)) ||
            (* unlabeled step *)
            ((String.get stepnm ((String.length stepnm) - 1)) = '>'));
        let sm = if (StringMap.mem stepnm sm) then
            StringMap.remove stepnm sm else sm in
        let adj_step scx =
          Expr.Visit.adj scx (Defn (Operator (
                stepnm @@ st,
                At false @@ nowhere) @@ st, Proof
          Always, Visible, Local) @@ st) in
        (* sequent's context level *)
        let rec hyps_level hs =
            match Deque.front hs with
            | None -> 0
            | Some (h, hs) ->
                let h_level = Expr.Levels.get_level h in
                let hs_level = hyps_level hs in
                max h_level hs_level
            in
        match st.core with
        | Forget m ->
            let nfacts = Deque.size cx in
            let cx = Deque.map begin
                         fun n h -> match h.core with
                           | Fact (e, Visible, tm) when m + n < nfacts ->
                               Fact (e, Hidden, tm) @@ h
                           | _ -> h
                       end cx in
            (((level, sm), cx),
                Forget m @@ st)
        | Hide usables ->
            let cx = List.fold_left (set_defn Hidden) cx usables.defs in
            let cx = List.fold_right (set_expr Hidden) usables.facts cx in
            (((level, sm), cx),
                Hide usables @@ st)
        | Use ({defs = []; facts = [f]}, only) ->
            let tm = Always in
            let cx = Deque.snoc cx (Fact (f, Visible, tm) @@ f) in
            (((level, sm), cx),
                Use ({defs = []; facts = [f]}, only) @@ st)
        | Assert (sq, prf) ->
            (* ignore (self#sequent scx sq) ; *)
            let sq_expr = Expr.Levels.compute_level cx (noprops (Sequent sq)) in
            let sq = match sq_expr.core with
                | Sequent sq -> sq
                | _ -> assert false
                in
            let proof_level = ref 0 in
            let prf =
                let level_hyps = hyps_level sq.context in
                (* store (assumption) level of sequent context *)
                let sm = StringMap.add stepnm (st, cx, level_hyps) sm in
                let scx = ((proof_level, sm), cx) in
                (* context changes *)
                let scx = Expr.Visit.adjs scx (Deque.to_list sq.context) in
                let scx = Proof.Visit.bump scx 1 in
                let scx = adj_step scx in
                let scx = Proof.Visit.bump scx 1 in
                self#proof scx prf in
            let scx = adj_step scx in
            let scx = Proof.Visit.bump scx 1 in
            let ((_, sm), cx) = scx in
            (* level computation *)
            let sq_level = Expr.Levels.get_level sq_expr in
            (*
            print_int sq_level;
            print_string "\n";
            print_int !proof_level;
            print_string "\n";
            *)
            level := if !proof_level < 2 then
                !proof_level
            else
                min sq_level !proof_level;
            (*
            print_int !level;
            print_string "\n";
            *)
            (* store (assumption) level of sequent and its proof *)
            let sm = StringMap.add stepnm (st, cx, !level) sm in
            (((level, sm), cx),
                Assert (sq, prf) @@ st)
        | Suffices (sq, prf) ->
            (* ignore (self#sequent scx sq) ; *)
            let sq_expr = Expr.Levels.compute_level cx (noprops (Sequent sq)) in
            let sq = match sq_expr.core with
                | Sequent sq -> sq
                | _ -> assert false
                in
            let proof_level = ref 0 in
            let prf =
              let scx = adj_step scx in
              let scx = Proof.Visit.bump scx 1 in
              let ((_, sm), cx) = scx in
              let sq_level = Expr.Levels.get_level sq_expr in
              level := sq_level;
              let sm = StringMap.add stepnm (st, cx, !level) sm in
              let scx = ((proof_level, sm), cx) in
              self#proof scx prf
            in
            let level_hyps = hyps_level sq.context in
            (* store (assumption) level of sequent context *)
            let sm = StringMap.add stepnm (st, cx, level_hyps) sm in
            let scx = ((proof_level, sm), cx) in
            (* context changes *)
            let scx = Expr.Visit.adjs scx (Deque.to_list sq.context) in
            let scx = Proof.Visit.bump scx 1 in
            let scx = adj_step scx in
            let scx = Proof.Visit.bump scx 1 in
            (scx,
                Suffices (sq, prf) @@ st)
        | Pcase _
        | Have _
        | Take _
        | Witness _
        | Pick _ ->
            assert false  (* after `Proof.Simplify.simplify` *)
        | _ ->
            let sm = StringMap.add stepnm (st, cx, 1) sm in
            let scx = ((level, sm), cx) in
            super#step scx st

    method check_usable pf ((level, sm), cx) usables only =
        (* computation of proof's assumption expression level *)
        let check_fact cx fact =
            begin match fact.core with
            | Ix n -> begin
            let hyp = E_t.get_val_from_id cx n in
            let cx_ = Expr.T.cx_front cx n in
                match hyp.core with
                | Fact (expr, Visible, _) ->
                    print_string (Expr.Fmt.string_of_expr cx_ expr);
                    assert false
                (* checking referenced steps *)
                | Defn ({core=Operator (name, _)}, _, Visible, _) ->
                    (*
                    print_string "Step number:\n";
                    print_string name.core;
                    *)
                    let nm = name.core in
                    if (String.contains_from nm 0 '<') then begin
                        if (StringMap.mem nm sm) then begin
                            let (step, cx, step_level) = StringMap.find nm sm in
                            level := max step_level !level
                        end end
                | _ -> ()
                end
            (* checking of expressions in the BY statement *)
            | _ ->
                let fact = Expr.Levels.compute_level cx fact in
                let expr_level = Expr.Levels.get_level fact in
                level := max expr_level !level
            end
            in
        (* checking assumptions in the step's context *)
        if not only then begin
        let check_assumptions n hyp =
            match hyp.core with
            | Fact ({core=At _}, _, _) -> ()  (* dummy steps *)
            | Fact (expr, Visible, _) ->
                let cx_ = Expr.T.cx_front cx ((Deque.size cx) - n) in
                (*
                print_string "Fact:\n";
                print_string (Expr.Fmt.string_of_expr cx_ expr);
                *)
                check_fact cx_ expr
            | _ -> ()
            in
        Deque.iter check_assumptions cx
        end;

        let max_level = ref 0 in
        let check_step cx fact =
            begin match fact.core with
            | Ix n -> begin
                let hyp = E_t.get_val_from_id cx n in
                match hyp.core with
                | Defn ({core=Operator (name, _)}, _, Visible, _) ->
                    let nm = name.core in
                    (* is this a step number ? *)
                    if (String.contains_from nm 0 '<') then begin
                        if (StringMap.mem nm sm) then begin
                            (* print_string ("Found stored step " ^ nm ^ "\n"); *)
                            let (step, cx, step_level) = StringMap.find nm sm in
                            max_level := max step_level !max_level
                        end end
                | _ -> ()
                end
            | _ ->
                let fact = Expr.Levels.compute_level cx fact in
                let expr_level = Expr.Levels.get_level fact in
                max_level := max expr_level !max_level
            end
            in
        let check_steps n hyp =
            match hyp.core with
            (*
            | Defn ({core=Operator (name, _)}, _, Visible, _) ->
                let nm = name.core in
                (* is this a step number ? *)
                if (String.contains_from nm 0 '<') then begin
                    if (StringMap.mem nm sm) then begin
                        (* print_string ("Found stored step " ^ nm ^ "\n"); *)
                        let (step, cx, step_level) = StringMap.find nm sm in
                        (*
                        if (step_level > 1) && (!max_level <= 1) then
                            print_string nm;
                        *)
                        max_level := max step_level !max_level;
                    end end
            *)
            | Fact ({core=At _}, _, _) -> ()  (* dummy steps *)
            | Fact (expr, Visible, _) ->
                let cx_ = Expr.T.cx_front cx ((Deque.size cx) - n) in
                (*
                print_string (Expr.Fmt.string_of_expr cx_ expr);
                print_string "\n";
                *)
                check_step cx_ expr
            | _ -> ()
            in
        (* find proof directive in the context *)
        let found = ref false in
        let find_proof_directive n hyp =
            match hyp.core with
            | Fact (expr, Visible, _) ->
                let cx_ = Expr.T.cx_front cx ((Deque.size cx) - n) in
                begin match expr.core with
                | Ix n -> begin
                    let hyp = E_t.get_val_from_id cx_ n in
                    match hyp.core with
                    | Defn ({core=Bpragma (name, _, _)}, _, _, _) ->
                        found := !found || (name.core = "ENABLEDaxioms")
                    | _ -> ()
                    end
                | _ -> ()
                end
            | _ -> ()
            in
        Deque.iter find_proof_directive cx;

        if !found then begin
            (* print_string "Found ENABLEDaxioms\n"; *)
            Deque.iter check_steps cx;
            if (!max_level > 1) then
                begin
                Util.eprintf ~at:pf "%s"
                    ("ENABLEDaxioms depends on assumption of expression " ^
                    "level > 1");
                (*
                Util.eprintf "%a@" (Proof.Fmt.pp_print_proof (cx, Ctx.dot)) pf
                *)
                assign pf enabledaxioms false
                end
            else
                assign pf enabledaxioms true
            end
        else
            assign pf enabledaxioms true
end


let check_enabled_axioms_usage = object (self: 'self)
    inherit [unit]
        Proof.Visit.iter as super

    val mutable found_enabled_axioms: bool = false

    method find_enabled_axioms cx pf =
        found_enabled_axioms <- false;
        let scx = ((), cx) in
        self#proof scx pf;
        found_enabled_axioms

    method proof ((_, cx) as scx) pf = match pf.core with
        | Omitted _ | Error _ -> ()
        | Obvious ->
            self#check_usable pf scx {facts=[]; defs=[]} false
        | By (usable, onl) ->
            self#check_usable pf scx usable onl
        | Steps (inits, qed) ->
            let scx = self#steps scx inits in
            self#proof scx (get_qed_proof qed);

    method step ((_, cx) as scx) st =
        let stepnm = string_of_stepno (Property.get st Props.step) in
        let adj_step scx =
          Expr.Visit.adj scx (Defn (Operator (
                stepnm @@ st,
                At false @@ nowhere) @@ st, Proof
          Always, Visible, Local) @@ st) in
        match st.core with
        | Forget m ->
            let nfacts = Deque.size cx in
            let cx = Deque.map begin
                         fun n h -> match h.core with
                           | Fact (e, Visible, tm) when m + n < nfacts ->
                               Fact (e, Hidden, tm) @@ h
                           | _ -> h
                       end cx in
            ((), cx)
        | Hide usables ->
            let cx = List.fold_left (set_defn Hidden) cx usables.defs in
            let cx = List.fold_right (set_expr Hidden) usables.facts cx in
            ((), cx)
        | Use ({defs = []; facts = [f]}, only) ->
            let tm = Always in
            let cx = Deque.snoc cx (Fact (f, Visible, tm) @@ f) in
            ((), cx)
        | Assert (sq, prf) ->
            let () =
                (* context changes *)
                let scx = Expr.Visit.adjs ((), cx) (Deque.to_list sq.context) in
                let scx = Proof.Visit.bump scx 1 in
                let scx = adj_step scx in
                let scx = Proof.Visit.bump scx 1 in
                self#proof scx prf in
            let scx = adj_step scx in
            let scx = Proof.Visit.bump scx 1 in
            let (_, cx) = scx in
            ((), cx)
        | Suffices (sq, prf) ->
            let () =
              let scx = adj_step scx in
              let scx = Proof.Visit.bump scx 1 in
              let (_, cx) = scx in
              self#proof ((), cx) prf
            in
            let scx = ((), cx) in
            let scx = Expr.Visit.adjs scx (Deque.to_list sq.context) in
            let scx = Proof.Visit.bump scx 1 in
            let scx = adj_step scx in
            let scx = Proof.Visit.bump scx 1 in
            scx
        | Pcase _
        | Have _
        | Take _
        | Witness _
        | Pick _ ->
            assert false  (* after `Proof.Simplify.simplify` *)
        | _ ->
            let scx = ((), cx) in
            super#step scx st

    method check_usable pf (_, cx) usables only =
        let found = ref false in
        (* find proof directive in the context *)
        let cx_iter n hyp =
            match hyp.core with
            | Fact (expr, _, _) ->
                let cx_ = Expr.T.cx_front cx ((Deque.size cx) - n) in
                begin match expr.core with
                | Ix n -> begin
                    let hyp = E_t.get_val_from_id cx_ n in
                    match hyp.core with
                    | Defn ({core=Bpragma (name, _, _)}, _, _, _) ->
                        found := !found || (name.core = "ENABLEDaxioms")
                    | _ -> ()
                    end
                | _ -> ()
                end
            | _ -> ()
            in
        Deque.iter cx_iter cx;
        if !found then begin
            found_enabled_axioms <- true;
            end
end

(******************************************************************************)

let assert_module_exists name mcx mu =
    if not (StringMap.mem name mcx) then begin
      Errors.err ~at:mu "Module %S unknown\n%!" name;
      failwith "Module.Elab.normalize";
    end


(* is_anon = false => not yet anonymised *)
let rec normalize mcx cx m =
  let origbody = m.core.body in
  let prefix = ref Deque.empty in
  let emit mu = prefix := Deque.snoc !prefix mu in
  let gencx = cx in
  (* let submod_obs: Proof.T.obligation list ref = ref [] in *)
  let rec spin mcx cx = function
    | [] -> cx
    | (mu, is_anon) :: mus ->
      begin
        let print cx mu s =
            let hs = hyps_of_modunit mu in
            let pr_mu ff =
                ignore (M_fmt.pp_print_modunit (cx, Ctx.dot) ff mu) in
            let pr_seq ff =
                ignore (Expr.Fmt.pp_print_sequent (cx, Ctx.dot) ff
                               {context = Deque.of_list hs;
                                active = (At false) @@ mu}) in
            Util.eprintf ~debug:"inst" ~at:mu
                         "((%s)) modunit = %thyps = %t@." s
                         pr_mu pr_seq
            in
        let continue mcx cx mu s =
            emit mu;
            print cx mu s;
            let cx = Deque.append_list cx (hyps_of_modunit mu) in
            spin mcx cx mus
        in
        let const_visitor =
            object inherit Expr.Constness.const_visitor end in
        let redundant nm = match nm with
            | None -> false
            | Some nm ->
                let what = Expr.Anon.hyp_is_named nm.core in
                Deque.find cx what != None
        in
        let map_proof cx nm sq pf mu m = begin
        (* add a definition for the theorem if it is named,
        to the context `cx` within the theorem's proof
        *)
            let (cx, sq) =
                match nm with
                    | Some nm ->
                        let op_sq = exprify_sequent sq @@ nm in
                        let op = Operator (nm, op_sq) @@ mu in
                        (Deque.snoc
                            cx
                            (Defn (op, Proof Always, Visible, Export) @@ mu),
                            app_sequent (shift 1) sq)
                    | None ->
                        (cx, sq)
                    in
            (* add the theorem's hypotheses to the context `cx` within
            the theorem's proof
            *)
            let cx = Deque.append cx sq.context in
            let time_flag = Expr.Temporal_props.check_time_change
                sq.context Always in
            Util.eprintf ~debug:"simplify" ~at:mu
                "@[<v0>Simplifying:@,  THEOREM %a@,  %a@]"
                    (Expr.Fmt.pp_print_expr (Deque.empty, Ctx.dot))
                    (exprify_sequent sq @@ mu)
                    (Proof.Fmt.pp_print_proof (cx, Ctx.dot))
                    pf;
            (*let pf =
            let visitor1 = object
            inherit [unit] Proof.Visit.map as proofer
            inherit Expr.Constness.const_visitor
            method proof scx pf = proofer#proof scx pf
            end
            in
            visitor1#proof ((),cx) pf in*)
            let pf = anon#mproof mcx ([], cx) pf in
            (* comment this condition check to generate proofs for
            all modules, including submodules, even when the parser
            marks submodules as not important.
            *)
            if m.core.important then begin
                let pf = Proof.Simplify.simplify cx sq.active pf time_flag in
                    (* ((ref 0, StringMap.empty), cx) pf; *)
                let has = check_enabled_axioms_usage#find_enabled_axioms
                    cx pf in
                let pf = if has then check_enabled_axioms_map#proof
                    ((ref 0, StringMap.empty), cx) pf else pf in
                pf
                end
            else
                pf
            end
            in
        let create_instance inst mcx cx mu ~local ~iname =
            assert_module_exists inst.inst_mod mcx mu;
            Util.eprintf ~debug:"inst" ~at:mu
                "Instantiating: %t@."
                (fun ff -> ignore (M_fmt.pp_print_modunit (cx, Ctx.dot) ff mu));
            let submus =
                instantiate anon mcx cx (inst @@ mu)
                    ~local:local ~iname:iname in
            (* iterate over the list of statements introduced by `INSTANCE`,
            concatenated with the remaining module units (the list `mus`).
            *)
            let is_anon = true in
            let same x = (x, is_anon) in
            let submus = List.map same submus in
            spin mcx cx (submus @ mus)
            in
        match mu.core with
        | Anoninst (inst, loc) ->
            create_instance inst mcx cx mu ~local:loc ~iname:("" @@ mu)
        | Definition ({core = Instance (nm, inst)}, _, _, ex) ->
            create_instance inst mcx cx mu ~local:ex ~iname:nm
        | Definition ({core = Operator (nm, _)} as df, wd, vis, ex)
            (* treat pragma definitions as usual operator definitions *)
        | Definition ({core = Bpragma (nm, _, _)} as df, wd, vis, ex) ->
          begin
            let df = if is_anon then df else anon#defn ([], cx) df in
            let df = const_visitor#defn ((), cx) df in
            let mu = Definition (df, wd, vis, ex) @@ mu in
            (* merge identical operator definitions *)
            let h = Defn (df, wd, vis, ex) @@ mu in
            match Deque.find ~backwards:true cx
                             (Expr.Anon.hyp_is_named nm.core) with
            | Some (x, ({core = Defn (d, _, _, _)} as oh)) ->
                let oh = app_hyp (shift (x + 1)) oh in
                let eq =
                  match d.core with
                  | Recursive _ -> true
                  | _ -> Expr.Eq.hyp oh h
                in
                if eq then begin
                  let mus,flags = List.split mus in
                  let (_, mus) =
                    M_subst.app_modunits (scons (Ix (x + 1) @@ h) (shift 0)) (mus) in
                  let mus = List.combine mus flags in
                    spin mcx cx mus
                end else begin
                  continue mcx cx mu "Definition1"
                end
            | _ ->
                continue mcx cx mu "Definition2"
          end
        | Recursives _
        | Definition ({core = Recursive _}, _, _, _)
            (* FIXME eliminate redundant definitions here too *)
        | Constants _
        | Variables _ -> continue mcx cx mu "Variables"
        | Axiom (nm, e) ->
            if redundant nm then begin
              spin mcx cx mus
            end else begin
              let e = anon#mexpr mcx ([], cx) e in
              let e = const_visitor#expr ((), cx) e in
              let mu = Axiom (nm, e) @@ mu in
              continue mcx cx mu "Axiom"
            end
        | Theorem (nm, sq, naxs, pf, pf_orig, summ) ->
            let (nm, pf, pf_orig) =
              if redundant nm then begin
                let name =
                  match nm with
                  | Some n -> ("(redundant)" ^ n.core) @@ n
                  | _ -> assert false
                in
                (Some name, Obvious @@ pf, Obvious @@ pf_orig)
              end else (nm, pf, pf_orig)
            in
            begin
              let (_, sq) = anon#msequent mcx ([], cx) sq in
              let (_, sq) = const_visitor#sequent ((),cx) sq in
              let pf = map_proof cx nm sq pf mu m in
              (* we apply it later to obligations so we can skip the proofs
               * themselves *)
              (*
                let pf =
                let visitor = object
                  inherit [unit] Proof.Visit.map as proofer
                  inherit Expr.Constness.const_visitor
                  method proof scx pf = proofer#proof scx pf
                end
                in
                visitor#proof ((),cx) pf in
              let pf =
                let visitor = object
                  inherit [unit] Proof.Visit.map as proofer
                  inherit Expr.Leibniz.leibniz_visitor
                  method proof scx pf = proofer#proof scx pf
                end
                in
                visitor#proof ((),cx) pf in *)
              let mu = Theorem (nm, sq, naxs, pf, pf_orig, summ) @@ mu in
              continue mcx cx mu "Theorem"
            end
        | Mutate (uh, us) ->
            let us = anon#musable mcx ([], cx) us in
            let mu = Mutate (uh, us) @@ mu in
            continue mcx cx mu "Mutate"
        | Submod m ->
            let (mcx, m, _) = normalize mcx cx m in
            (* let (m, obs, summ) = M_gen.generate gencx m in
            submod_obs := List.append !submod_obs obs; *)
            let mu = Submod m @@ mu in
            continue mcx cx mu "Submod"
        end
  in
  let _cx = spin mcx cx (List.map (fun x -> x, false) m.core.body) in
    Util.eprintf ~debug:"noprinting" "%a"
        (fun fmt cx -> ignore (
            Expr.Fmt.pp_print_sequent (Deque.empty, Ctx.dot) fmt cx))
        ({context = _cx ; active = Ix(1) @@ m});
  let prefix = Deque.to_list !prefix in
  let maybe_salt mu =
    if has mu salt_prop then begin
      let mu = match mu.core with
        | Definition ({core = Operator (nm, e)} as df, wd, vis, ex) ->
            Definition (Operator (salt nm, e) @@ df, wd, vis, ex) @@ mu
        | Definition ({core = Instance (nm, ins)} as df, wd, vis, ex) ->
            Definition (Instance (salt nm, ins) @@ df, wd, vis, ex) @@ mu
        | _ ->
            Errors.bug ~at:mu "Module.Elab.normalize: has salt_prop"
      in remove mu salt_prop
    end else mu
  in
  let prefix = List.map maybe_salt prefix in
  let m = { m.core with body = prefix } @@ m in
  let (m, obs, summ) =
    if m.core.important then M_gen.generate gencx m
    else (m, [], {
            sum_total = 0 ;
            sum_absent = 0, [] ;
            sum_omitted = 0, [] ;
            sum_suppressed = 0, []
          })
  in
  (* let all_obs = List.append obs !submod_obs in *)
  let m = match m.core.stage with
    | Special -> m
    | Flat ->
        let stage = Final { final_named  = origbody
                          (* ; final_obs    = Array.of_list all_obs *)
                          ; final_obs    = Array.of_list obs
                          ; final_status = (Unchecked, summ)
                          }
        in { m.core with stage = stage } @@ m
    | Parsed ->
        Errors.bug ~at:m "Elaborating an unflattened module"
    | Final _ ->
        Errors.bug ~at:m "Elaborating a final module"
  in
  let m = { m.core with defdepth = Deque.size gencx } @@ m in
  let mcx = StringMap.add m.core.name.core m mcx in
  (mcx, m, summ)
