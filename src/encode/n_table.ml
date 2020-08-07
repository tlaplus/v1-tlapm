(*
 * encode/table.ml --- table of symbols used to encode POs
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Type.T
open Property

module A = N_axioms


(* {3 Symbols of TLA+} *)

type tla_smb =
  (* Logic *)
  | Choose of ty
  (* Set Theory *)
  | Mem of ty
  | SubsetEq of ty
  | SetEnum of int * ty
  | Union of ty
  | Subset of ty
  | Cup of ty
  | Cap of ty
  | SetMinus of ty
  | SetSt of ty
  | SetOf of ty list * ty
  (* Primitive Sets *)
  | Booleans
  | Strings
  | Ints
  | Nats
  | Reals
  (* Functions *)
  | Arrow of ty * ty
  | Domain of ty * ty
  | FcnApp of ty * ty
  | Fcn of ty * ty
  | Except of ty * ty
  (* Special *)
  | Any of ty       (** Random element of a type *)
  | Ucast of ty     (** Cast from any type to uninterpreted *)
  | Uver of tla_smb (** Uninterpreted VERsion of a symbol *)

type family =
  | Logic
  | Sets
  | Booleans
  | Strings
  | Tuples
  | Functions
  | Records
  | Sequences
  | Arithmetic
  | Special

let rec get_tlafam = function
  | Choose _ ->
      Logic
  | Mem _ | SubsetEq _ | SetEnum _ | Union _ | Subset _
  | Cup _ | Cap _ | SetMinus _ | SetSt _ | SetOf _ ->
      Sets
  | Booleans ->
      Booleans
  | Strings ->
      Strings
  | Ints | Nats | Reals ->
      Arithmetic
  | Arrow _ | Domain _ | FcnApp _ | Fcn _ | Except _ ->
      Functions
  | Uver smb ->
      get_tlafam smb
  | Any _ | Ucast _ ->
      Special


exception No_value

let smbtable_aux = function
  | Choose ty ->
      [],
      [ A.choose (Some ty) ]
  | SubsetEq ty ->
      [ Mem ty ],
      [ A.subseteq (Some ty) ]
  | SetEnum (n, ty) ->
      [ Mem ty ],
      [ A.setenum n (Some ty) ]
  | Union ty ->
      [ Mem ty ],
      [ A.union (Some ty) ]
  | Subset ty ->
      [ Mem ty ],
      [ A.subset (Some ty) ]
  | Cup ty ->
      [ Mem ty ],
      [ A.cup (Some ty) ]
  | Cap ty ->
      [ Mem ty ],
      [ A.cap (Some ty) ]
  | SetMinus ty ->
      [ Mem ty ],
      [ A.setminus (Some ty) ]
  | SetSt ty ->
      [ Mem ty ],
      [ A.setst (Some ty) ]
  | SetOf (tys, ty) ->
      List.map (fun ty -> Mem ty) tys @
      [ Mem ty ],
      [ A.setof (List.length tys) (Some (tys, ty)) ]
  | Arrow (ty1, ty2) ->
      [ Mem ty1
      ; Mem ty2
      ; Domain (ty1, ty2)
      ; FcnApp (ty1, ty2) ],
      [ A.arrow (Some (ty1, ty2)) ]
  | Fcn (ty1, ty2) ->
      [ Mem ty1
      ; Domain (ty1, ty2)
      ; FcnApp (ty1, ty2) ],
      [ A.domain (Some (ty1, ty2))
      ; A.fcnapp (Some (ty1, ty2)) ]
  | Uver (Choose _) ->
      [ Any (TAtom TU) ],
      [ A.choose None ]
  | Uver (SubsetEq _) ->
      [ Uver (Mem TUnknown) ],
      [ A.subseteq None ]
  | Uver (SetEnum (n, _)) ->
      [ Uver (Mem TUnknown) ],
      [ A.setenum n None ]
  | Uver (Union _) ->
      [ Uver (Mem TUnknown) ],
      [ A.union None ]
  | Uver (Subset _) ->
      [ Uver (Mem TUnknown) ],
      [ A.subset None ]
  | Uver (Cup _) ->
      [ Uver (Mem TUnknown) ],
      [ A.cup None ]
  | Uver (Cap _) ->
      [ Uver (Mem TUnknown) ],
      [ A.cap None ]
  | Uver (SetMinus _) ->
      [ Uver (Mem TUnknown) ],
      [ A.setminus None ]
  | Uver (SetSt _) ->
      [ Uver (Mem TUnknown) ],
      [ A.setst None ]
  | Uver (SetOf (tys, _)) ->
      List.map (fun _ -> Uver (Mem TUnknown)) tys @
      [ Uver (Mem TUnknown) ],
      [ A.setof (List.length tys) None ]
  | Uver (Arrow _) ->
      [ Uver (Mem TUnknown)
      ; Uver (Mem TUnknown)
      ; Uver (Domain (TUnknown, TUnknown))
      ; Uver (FcnApp (TUnknown, TUnknown)) ],
      [ A.arrow None ]
  | Uver (Fcn _) ->
      [ Uver (Mem TUnknown)
      ; Uver (Domain (TUnknown, TUnknown))
      ; Uver (FcnApp (TUnknown, TUnknown)) ],
      [ A.domain None
      ; A.fcnapp None ]
  | _ ->
      raise No_value

let smbtable smb =
  try Some (smbtable_aux smb)
  with No_value -> None


(* {3 Symbol Data} *)

type smb =
  { smb_fam  : family
  ; smb_name : string
  ; smb_sch  : ty_sch option (* FIXME remove option *)
  ; smb_kind : ty_kind       (* FIXME remove *)
  ; smb_ord  : int
  ; smb_defn : tla_smb option
  }

let mk_smb fam nm ?sch:sch k =
  let d = ord k in
  if d < 0 || d > 2 then
    let mssg = ("Attempt to create symbol '" ^ nm ^ "' \
                of order " ^ string_of_int d) in
    Errors.bug mssg
  else
    { smb_fam = fam
    ; smb_name = nm
    ; smb_sch = sch
    ; smb_kind = k
    ; smb_ord = ord k
    ; smb_defn = None
    }

let mk_snd_smb fam nm ints outt =
  let ks =
    List.map begin fun (tys, ty) ->
      mk_fstk_ty tys ty
    end ints
  in
  let k = mk_kind_ty ks outt in
  let targs =
    List.map begin function
      | [], ty -> TRg ty
      | tys, ty -> TOp (tys, ty)
    end ints
  in
  let sch = TSch ([], targs, outt) in
  mk_smb fam nm ~sch:sch k

let mk_fst_smb fam nm ints outt =
  let k = mk_fstk_ty ints outt in
  let sch = TSch ([], List.map (fun ty -> TRg ty) ints, outt) in
  mk_smb fam nm ~sch:sch k

let mk_cst_smb fam nm ty =
  let k = mk_cstk_ty ty in
  let sch = TSch ([], [], ty) in
  mk_smb fam nm ~sch:sch k

let get_fam smb = smb.smb_fam
let get_name smb = smb.smb_name
let get_sch smb = Option.get smb.smb_sch
let get_kind smb = smb.smb_kind
let get_ord smb = smb.smb_ord
let get_defn smb = smb.smb_defn

module OrdSmb = struct
  type t = smb
  let compare smb1 smb2 =
    let fam1 = get_fam smb1 in
    let fam2 = get_fam smb2 in
    match Pervasives.compare fam1 fam2 with
    | 0 ->
        let nm1 = get_name smb1 in
        let nm2 = get_name smb2 in
        Pervasives.compare nm1 nm2
    | n -> n
end

let smb_prop = make "Encode.Table.smb_prop"

let has_smb a = has a smb_prop
let set_smb smb a = assign a smb_prop smb
let get_smb a = get a smb_prop


module SmbSet = Set.Make (OrdSmb)
module SmbMap = Map.Make (OrdSmb)


(* Replace every type with U, except positive occurrences of Bool *)
let u_kind k =
  let rec u_kind_pos (TKind (ks, ty)) =
    let ks = List.map u_kind_neg ks in
    let ty =
      match ty with
      | TAtom TBool -> ty_bool
      | _ -> ty_u
    in
    TKind (ks, ty)
  and u_kind_neg (TKind (ks, ty)) =
    let ks = List.map u_kind_pos ks in
    TKind (ks, ty_u)
  in
  u_kind_pos k

let u_smb smb =
  { smb with
    smb_name = smb.smb_name (* NOTE /!\ This works in practise as long as
                             * u_smb is only called on standards symbols
                             * with type argument 'TUnknown' *)
  ; smb_kind = u_kind smb.smb_kind
  }


(* NOTE An "unknown" type attached to a symbol leads to no suffix.
 * That may be dangerous if you're not careful. *)
let suffix s ss =
  let ss = List.filter (fun s -> String.length s <> 0) ss in
  String.concat "__" (s :: ss)

let rec type_to_string_aux ty =
    match ty with
    | TUnknown -> "Unknown"
    | TVar a -> "Var" ^ a
    | TAtom TU -> "U"
    | TAtom TBool -> "Bool"
    | TAtom TInt -> "Int"
    | TAtom TReal -> "Real"
    | TAtom TStr -> "String"
    | TSet ty ->
        let s = type_to_string_aux ty in
        "Set" ^ s
    | TArrow (ty1, ty2) ->
        let s1 = type_to_string_aux ty1 in
        let s2 = type_to_string_aux ty2 in
        "Arrow" ^ s1 ^ s2
    | TProd tys ->
        let ss = List.map type_to_string_aux tys in
        List.fold_left (^) "Prod" ss

let type_to_string ty =
  match ty with
  | TUnknown -> ""
  | _ -> type_to_string_aux ty

let choose ty =
  let id = suffix "Choose" [ type_to_string ty ] in
  mk_snd_smb Logic id [ ([ty], ty_bool) ] ty

let mem ty =
  let id = suffix "Mem" [ type_to_string ty ] in
  mk_fst_smb Sets id [ ty ; TSet ty ] ty_bool
let subseteq ty =
  let id = suffix "Subseteq" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet ty ; TSet ty ] ty_bool
let setenum n ty =
  let id = suffix "SetEnum" [ string_of_int n ; type_to_string ty ] in
  mk_fst_smb Sets id (List.init n (fun _ -> ty)) (TSet ty)
let union ty =
  let id = suffix "Union" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet (TSet ty) ] (TSet ty)
let subset ty =
  let id = suffix "Subset" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet ty ] (TSet (TSet ty))
let cup ty =
  let id = suffix "Cup" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet ty ; TSet ty ] (TSet ty)
let cap ty =
  let id = suffix "Cap" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet ty ; TSet ty ] (TSet ty)
let setminus ty =
  let id = suffix "Setminus" [ type_to_string ty ] in
  mk_fst_smb Sets id [ TSet ty ; TSet ty ] (TSet ty)
let setst ty =
  let id = suffix "SetSt" [ type_to_string ty ] in
  mk_snd_smb Sets id [ ([], TSet ty) ; ([ty], ty_bool) ] (TSet ty)
let setof tys ty =
  let id = suffix "SetOf" (List.map type_to_string tys @ [ type_to_string ty ]) in
  mk_snd_smb Sets id ( (tys, ty) :: List.map (fun ty -> ([], TSet ty)) tys ) (TSet ty)

let set_boolean =
  let id = "Boolean" in
  mk_cst_smb Booleans id (TSet ty_bool)
let set_string =
  let id = "String" in
  mk_cst_smb Strings id (TSet ty_str)
let set_int =
  let id = "Int" in
  mk_cst_smb Arithmetic id (TSet ty_int)
let set_nat =
  let id = "Nat" in
  mk_cst_smb Arithmetic id (TSet ty_int)
let set_real =
  let id = "Real" in
  mk_cst_smb Arithmetic id (TSet ty_real)

let arrow ty1 ty2 =
  let id = suffix "Arrow" [ type_to_string ty1 ; type_to_string ty2 ] in
  mk_fst_smb Functions id [ TSet ty1 ; TSet ty2 ] (TSet (TArrow (ty1, ty2)))
let domain ty1 ty2 =
  let id = suffix "Domain" [ type_to_string ty1 ; type_to_string ty2 ] in
  mk_fst_smb Functions id [ TArrow (ty1, ty2) ] (TSet ty1)
let fcnapp ty1 ty2 =
  let id = suffix "FcnApp" [ type_to_string ty1 ; type_to_string ty2 ] in
  mk_fst_smb Functions id [ TArrow (ty1, ty2) ; ty1 ] ty2
let fcn ty1 ty2 =
  let id = suffix "Fcn" [ type_to_string ty1 ; type_to_string ty2 ] in
  mk_snd_smb Functions id [ ([], TSet ty1) ; ([ty1], ty2) ] (TArrow (ty1, ty2))
let except ty1 ty2 =
  let id = suffix "Except" [ type_to_string ty1 ; type_to_string ty2 ] in
  mk_fst_smb Functions id [ TArrow (ty1, ty2) ; ty1 ; ty2 ] (TArrow (ty1, ty2))

let product tys =
  let id = suffix "Product" (List.map type_to_string tys) in
  mk_fst_smb Tuples id tys (TSet (TProd tys))
let tuple tys =
  let id = suffix "Tuple" (List.map type_to_string tys) in
  mk_fst_smb Tuples id tys (TProd tys)

let any ty =
  let id = suffix "Any" [ type_to_string ty ] in
  mk_cst_smb Special id ty

let ucast ty =
  let id = suffix "Cast" [ type_to_string ty ] in
  mk_fst_smb Special id [ ty ] (TAtom TU)


let rec std_smb_aux = function
  | Choose ty -> choose ty
  | Mem ty -> mem ty
  | SubsetEq ty -> subseteq ty
  | SetEnum (n, ty) -> setenum n ty
  | Union ty -> union ty
  | Subset ty -> subset ty
  | Cup ty -> cup ty
  | Cap ty -> cap ty
  | SetMinus ty -> setminus ty
  | SetSt ty -> setst ty
  | SetOf (tys, ty) -> setof tys ty
  | Booleans -> set_boolean
  | Strings -> set_string
  | Ints -> set_int
  | Nats -> set_nat
  | Reals -> set_real
  | Arrow (ty1, ty2) -> arrow ty1 ty2
  | Domain (ty1, ty2) -> domain ty1 ty2
  | FcnApp (ty1, ty2) -> fcnapp ty1 ty2
  | Fcn (ty1, ty2) -> fcn ty1 ty2
  | Except (ty1, ty2) -> except ty1 ty2
  | Any ty -> any ty
  | Ucast ty -> ucast ty
  | Uver tla_smb -> u_smb (std_smb_aux tla_smb)

let std_smb tla_smb =
  { (std_smb_aux tla_smb) with smb_defn = Some tla_smb }
