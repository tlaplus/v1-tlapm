(*
 * module/dep.ml --- modules dependencies
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Property
open Util.Coll

open Expr.T
open M_t

(*let debug = Printf.eprintf;;*)

let external_deps m =
  let deps = ref Hs.empty in
  let instances = ref Hs.empty in
  let locals = ref Hs.empty in
  let submodules = ref Sm.empty in
  let mapper = object (self : 'self)
    inherit [unit] Proof.Visit.iter as super
    method defn scx df = begin match df.core with
      | Recursive (_, _) -> ()
      | Operator (_, e) ->
          self#expr scx e;
      | Bpragma (_,e,l) ->
          self#expr scx e;
      | Instance (_, ins) ->
          deps := Hs.add (ins.inst_mod @@ df) !deps ;
          instances := Hs.add (ins.inst_mod @@ df) !instances;
          List.iter begin
            fun (_, e) -> self#expr scx e
          end ins.inst_sub
    end ; super#defn scx df
  end in
  let rec visit mu = match mu.core with
    | Submod subm ->
        let m = subm.core in
        locals := Hs.add m.name !locals ;
        submodules := Sm.add m.name.core subm !submodules;
        List.iter (fun s -> deps := Hs.add s !deps) subm.core.extendees;
        List.iter visit m.body
    | Anoninst (ins, _) ->
        ignore (mapper#defn ((), Deque.empty)
                  (Instance ("_" @@ mu, ins) @@ mu))
    | _ ->
        List.iter begin
          fun h -> ignore (mapper#hyp ((), Deque.empty) h)
        end (hyps_of_modunit mu)
  in
  List.iter visit m.core.body ;
  deps := Hs.diff !deps !locals ;
  List.iter (fun s -> deps := Hs.add s !deps) m.core.extendees ;
  !deps, !locals, !submodules

(**
 @param mcx Sm (StringMap) of mule_ wrapped *)
let schedule mcx =

  (* computes the dependency order between modules*)
  let moddeps = Sm.fold begin
    fun key modul accum ->
      Sm.add key (let (e, _, _) = (external_deps modul) in e) accum
  end mcx Sm.empty in
  let seen = ref Hs.empty in
  let order = ref [] in
  let rec spin mn m =
    let mn = mn @@ m in
    if Hs.mem mn !seen then () else begin
      seen := Hs.add mn !seen ;
      Hs.iter begin
        fun dep ->
          spin dep.core (Sm.find dep.core mcx) ;
      end (Sm.find mn.core moddeps) ;
      order := m :: !order ;
    end
  in
  Sm.iter spin mcx ;
  let order = List.rev !order in
  let (mc, order) = List.fold_left begin
    fun (mc, order) m ->
      let m = match m.core.stage with
        | Special | Flat | Final _ -> m
        | Parsed -> fst (M_flatten.flatten mcx m Ss.empty)
      in
      let mc = Sm.add m.core.name.core m mc in
      (mc, m :: order)
  end (Sm.empty, []) order in
  let order = List.rev order in
  (mc, order)
;;
