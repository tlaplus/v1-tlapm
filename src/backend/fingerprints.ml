(*
 * fingerprints.ml --- fingerprints management
 *
 * Author: Denis Cousineau <denis(at)cousineau.eu>
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Proof.T


type ident =
  | No
  | Identvari of int
  | Identhypi of int
  | Identvar of string
  | Identhyp of string * string
  | IdentBPragma
;;

(************************)
(***** Stack module ******)
(************************)

module Stack : sig
  type 'a t = private { mutable stack : 'a array; mutable length : int }
  val create : int -> 'a -> 'a t
  val get : 'a t -> int -> 'a
  val set : 'a t -> int -> 'a -> unit
  val push : 'a t -> 'a -> unit
  val pop : 'a t -> 'a
  val popn : 'a t -> int -> 'a list
end = struct

  type 'a t =  { mutable stack : 'a array ;
                 mutable length : int }


  let create n a = {stack = (Array.make n a); length = 0}

  let copy h = let cp = Array.copy h.stack in {stack=cp; length = h.length}

  let get h i = Array.get h.stack (h.length -i)

  let set h i v = Array.set h.stack (h.length -i) v

  let push h v =
    let l = Array.length h.stack in
      if h.length = l then
        begin let b = Array.make (2*l) (Array.get h.stack 0) in
          Array.blit h.stack 0 b 0 l;
          Array.set b l v;
          h.stack <- b;
          h.length <- h.length + 1
        end
      else begin
          assert (h.length < l);
          (Array.set h.stack h.length v);
          h.length <- h.length + 1
      end

  let rec pushn h v n =
    if n = 0 then () else push h v; pushn h v (n-1)

  let pushl h l =
    List.iter (push h) l

  let pop h = let res = get h 1 in h.length <- h.length -1; res

  let rec popn h m =
    let nl = (h.length-m) in
      if nl < 0 then failwith "Backend.Fingerprints.Stack.pop"
      else match m with
        | 0 -> []
        | n -> (pop h)::(popn h (n-1))

end


let print_stack h =
  let l = h.Stack.length in
  Printf.printf "\n (%d)" l;
  let to_st v n = begin match v with
    | Identvari i -> Printf.sprintf " @%d@ Identvari [%d]" (l-n) i
    | Identhypi i -> Printf.sprintf " @%d@ Identhypi [%d]" (l-n) i
    | Identhyp (kind, s) -> Printf.sprintf " @%d@ Identhyp [%s,%s]" (l-n) kind s
    | Identvar s -> Printf.sprintf " @%d@ Identvar [%s]" (l-n) s
    | IdentBPragma -> "Identpragma"
    | No -> Printf.sprintf " @%d@ [NO]" (l-n) end in
    Array.iteri (fun i (v,r) -> Printf.printf "%s (%s);" (to_st v i) (string_of_bool !r)) h.Stack.stack;
    Printf.printf "\n%!"


let pushlvars h l = (*assert false;*)
  List.iter (Stack.push h) (List.map (fun v -> (Identvar v, ref false)) l)

(************************)
(* Compute fingerprints *)
(************************)


open Ext
open Property
open Expr.T
open Expr.Subst

(* Warning: never change the numbers.  If you add a new built-in, add it
   at the end. Otherwise, the old fingerprints will become wrong. *)
let builtin_to_int bi =
  match bi with
  | Builtin.TRUE -> 0
  | Builtin.FALSE -> 1
  | Builtin.Implies -> 2
  | Builtin.Equiv -> 3
  | Builtin.Conj -> 4
  | Builtin.Disj -> 5
  | Builtin.Neg -> 6
  | Builtin.Eq -> 7
  | Builtin.Neq -> 8
  | Builtin.STRING -> 9
  | Builtin.BOOLEAN -> 10
  | Builtin.SUBSET -> 11
  | Builtin.UNION -> 12
  | Builtin.DOMAIN -> 13
  | Builtin.Subseteq -> 14
  | Builtin.Mem -> 15
  | Builtin.Notmem -> 16
  | Builtin.Setminus -> 17
  | Builtin.Cap -> 18
  | Builtin.Cup -> 19
  | Builtin.Prime -> 20
  | Builtin.StrongPrime -> 21
  | Builtin.Leadsto -> 22
  | Builtin.ENABLED -> 23
  | Builtin.UNCHANGED -> 24
  | Builtin.Cdot -> 25
  | Builtin.Actplus -> 26
  | Builtin.Box _ -> assert false
  | Builtin.Diamond -> 27
  | Builtin.Nat -> 28
  | Builtin.Int -> 29
  | Builtin.Real -> 30
  | Builtin.Plus -> 31
  | Builtin.Minus -> 32
  | Builtin.Uminus -> 33
  | Builtin.Times -> 34
  | Builtin.Ratio -> 35
  | Builtin.Quotient -> 36
  | Builtin.Remainder -> 37
  | Builtin.Exp -> 38
  | Builtin.Infinity -> 39
  | Builtin.Lteq -> 40
  | Builtin.Lt -> 41
  | Builtin.Gteq -> 42
  | Builtin.Gt -> 43
  | Builtin.Divides -> 44
  | Builtin.Range -> 45
  | Builtin.Seq -> 46
  | Builtin.Len -> 47
  | Builtin.BSeq -> 48
  | Builtin.Cat -> 49
  | Builtin.Append -> 50
  | Builtin.Head -> 51
  | Builtin.Tail -> 52
  | Builtin.SubSeq -> 53
  | Builtin.SelectSeq -> 54
  | Builtin.OneArg -> 55
  | Builtin.Extend -> 56
  | Builtin.Print -> 57
  | Builtin.PrintT -> 58
  | Builtin.Assert -> 59
  | Builtin.JavaTime -> 60
  | Builtin.TLCGet -> 61
  | Builtin.TLCSet -> 62
  | Builtin.Permutations -> 63
  | Builtin.SortSeq -> 64
  | Builtin.RandomElement -> 65
  | Builtin.Any -> 66
  | Builtin.ToString -> 67
  | Builtin.Unprimable -> 68
  | Builtin.Irregular -> 69
;;

let bullet_to_int b =
  match b with
  | And -> 0
  | Or -> 1
  | Refs -> 2
;;

let quantifier_to_int q =
  match q with
  | Forall -> 0
  | Exists -> 1
;;

let modal_op_to_int m =
  match m with
  | Box -> 0
  | Dia -> 1
;;

let fairness_op_to_int f =
  match f with
  | Weak -> 0
  | Strong -> 1
;;

let rec time_to_string = function
  | Now -> "now"
  | Always -> "always"
  | NotSet -> assert false
;;

let to_string fp = Digest.to_hex (Digest.string (Buffer.contents fp))
(* FIXME: remove conversion to hex, watch out for FP files. *)

open Printf

let rec list ?(sep=fun buf -> bprintf buf ",") pr buf = function
  | [] -> ()
  | [x] -> pr buf x
  | x :: xs ->
      pr buf x ;
      sep buf ;
      list pr buf xs

let fp_bin buf = function
  | Builtin.Box false -> Buffer.add_string buf "$FakeBox"
  | Builtin.Box true  -> Buffer.add_string buf "$Box"
  | bin -> Printf.bprintf buf "$%d" (builtin_to_int bin);
;;

let rec fp_expr counthyp countvar stack buf e =
  let fps = fp_expr counthyp countvar stack in
  match e.core with
    | Ix n ->
       let c, r = Stack.get stack n in
       r := true;
       begin match c with
       | No -> bprintf buf "$V(%dSHOULD_NOT_APPEAR)" n
       | Identhyp (kind, s) ->
           Stack.set stack n (Identhypi (!counthyp),r);
           bprintf buf "$%s(%d)" kind !counthyp;
           incr counthyp
       | Identvar s ->
           Stack.set stack n (Identvari !countvar,r);
           bprintf buf "$PRM(%d)" !countvar;
           incr countvar
       | Identhypi i -> bprintf buf "$HYP(%d)" i
       | Identvari i -> bprintf buf "$PRM(%d)" i
       | IdentBPragma -> ()
       end
    | Opaque s -> Buffer.add_string buf s
    | Internal bin -> fp_bin buf bin
    | Lambda (vs, e) ->
        let n = List.length vs in
        let l = List.map (fun (a,_) -> a.core) vs in
        let bu = Buffer.create 17 in
          pushlvars stack l;
          bprintf bu "%a" (fp_expr counthyp countvar stack) e;
          bprintf buf "$Lam(";
          let vars = List.rev (Stack.popn stack n) in
            List.iter
              (fun v -> bprintf buf "%d." (match v with Identvari i,_ -> i
                                             | Identvar _,_ -> 0
                                             | _ -> assert false))
              vars;
            bprintf buf "%s)" (Buffer.contents bu);
    | Sequent sq ->
        fp_sequent stack buf sq
    | Apply (o, es) ->
        begin
          match o.core with
            | Ix n ->
                begin
                  match Stack.get stack n with
                    | IdentBPragma,_ -> ()
                    | _ -> bprintf buf "$OpApp(%a;%a)" fps o (list fps) es
                end
            |  _ ->  bprintf buf "$OpApp(%a;%a)" fps o (list fps) es
        end
    | With (e, _) ->
        fp_expr counthyp countvar stack buf e
    | If (e, f, g) ->
        bprintf buf "$If(%a,%a,%a)" fps e fps f fps g
    | List (q, es) ->
        bprintf buf "$List(%d;%a)" (bullet_to_int q) (list fps) es
    | Let (ds, e) ->
        fp_let counthyp countvar stack buf ds e
    | Quant (q, bs, e) ->
        let n = List.length bs in
        let l = List.map (fun (a,_,_) -> a.core) bs in
        (*let bounds = (fp_bounds count stack) bs in*)
         let bu = Buffer.create 17 in
           pushlvars stack l;
           bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           bprintf buf "$Quant(%d;" (quantifier_to_int q);
          let vars = (Stack.popn stack n) in
            bprintf buf "%s.%s)" (fp_bounds counthyp countvar stack vars bs) (Buffer.contents bu);
    | Tquant (q, vs, e) ->
        let n = List.length vs in
        let l = List.map (fun (a) -> a.core) vs in
          let bu = Buffer.create 17 in
           pushlvars stack l;
           bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           bprintf buf "$Tquant(%d" (quantifier_to_int q);
           let vars = List.rev (Stack.popn stack n) in
            List.iter
              (fun v -> bprintf buf "%d." (match v with Identvari i,_ -> i
              | Identvar _,_ -> 0
              | _ -> assert false))
              vars;
            bprintf buf "%s)" (Buffer.contents bu);
    | Choose (hint, None, e) ->
        let bu = Buffer.create 17 in
        Stack.push stack (Identvar hint.core,ref false);
          bprintf bu "%a" (fp_expr counthyp countvar stack) e;
          let v = Stack.pop stack in
        bprintf buf "$Ch(%d:%s)" (match v with Identvari i,_ -> i
              | Identvar _,_ -> 0
              | _ -> assert false) (Buffer.contents bu)
    | Choose (hint, Some d, e) ->
        let bu = Buffer.create 17 in
          Stack.push stack (Identvar hint.core, ref false);
          bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           let v = Stack.pop stack in
         bprintf buf "$Bch(%d:%a;%s)"
           (match v with Identvari i,_ -> i
              | Identvar _,_ -> 0
              | _ -> assert false)
           (fp_expr counthyp countvar stack) d
           (Buffer.contents bu)
    | SetSt (hint, d, e) ->
        let bu = Buffer.create 17 in
          Stack.push stack (Identvar hint.core, ref false);
          bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           let v = Stack.pop stack in
         bprintf buf "$SSt(%d:%a;%s)"
           (match v with Identvari i,_ -> i
              | Identvar _,_ -> 0
              | _ -> assert false)
           (fp_expr counthyp countvar stack) d
           (Buffer.contents bu)
    | SetOf (e, bs) ->
        let n = List.length bs in
        let l = List.map (fun (a,_,_) -> a.core) bs in
        (*let vars = String.concat "." l in*)
         let bu = Buffer.create 17 in
           pushlvars stack l;
           bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           bprintf buf "$Sof(";
          let vars = List.rev (Stack.popn stack n) in
            bprintf buf "%s.%s)" (fp_bounds counthyp countvar stack vars bs) (Buffer.contents bu);
    | SetEnum es ->
        bprintf buf "$Set(%a)" (list fps) es
    | Tuple es ->
        bprintf buf "$Tup(%a)" (list fps) es
    | Product es ->
        bprintf buf "$Prod(%a)" (list fps) es
    | Fcn (bs, e) ->
        let n = List.length bs in
        let l = List.map (fun (a,_,_) -> a.core) bs in
         let bu = Buffer.create 17 in
           pushlvars stack l;
           bprintf bu "%a" (fp_expr counthyp countvar stack) e;
           bprintf buf "$Fcn(";
          let vars = List.rev (Stack.popn stack n) in
            bprintf buf "%s.%s)" (fp_bounds counthyp countvar stack vars bs) (Buffer.contents bu);
    | FcnApp (f, es) ->
        bprintf buf "$FcnApp(%a;%a)"
          fps f (list fps) es
    | Arrow (e, f) ->
        bprintf buf "$Arrow(%a,%a)"
          fps e fps f
    | Rect fs ->
        bprintf buf "$Rect(%a)" (list (fp_field counthyp countvar stack)) fs
    | Record fs ->
        bprintf buf "$Record(%a)" (list (fp_field counthyp countvar stack)) fs
    | Except (e, xs) ->
        bprintf buf "$Except(%a,%a)"
          fps e (list (fp_exspec counthyp countvar stack)) xs
    | Dot (e, f) ->
        bprintf buf "$Dot(%a,%s)" fps e f
    | Sub (m, e, f) ->
        bprintf buf "$Sub(%d,%a,%a)" (modal_op_to_int m) fps e fps f
    | Tsub (m, e, f) ->
        bprintf buf "$Tsub(%d,%a,%a)" (modal_op_to_int m) fps e fps f
    | Fair (m, e, f) ->
        bprintf buf "$Fair(%d,%a,%a)" (fairness_op_to_int m) fps e fps f
    | Case (arms, Some oth) ->
        bprintf buf "$Case(%a,%a)"
          (list (fp_arm counthyp countvar stack)) arms fps oth
    | Case (arms, None) ->
        bprintf buf "$Case(%a,)"
          (list (fp_arm counthyp countvar stack)) arms
    | String s ->
        bprintf buf "%S" s
    | Num (m, n) ->
        bprintf buf "$Num(%s,%s)" m n
    | At _ ->
        Buffer.add_string buf "$At"
    | Parens (e, _) ->
        fp_expr counthyp countvar stack buf e
    | Bang _ ->
        Errors.bug ~at:e "Expr.Fingerprint: Bang"


and fp_sequent stack buf sq =
  let counthyp = ref 1 in
  let countvar = ref 1 in
  let rec spin stack cx = match Deque.front cx with
    | None ->
        bprintf buf "$Goal(%a)" (fp_expr counthyp countvar stack) sq.active
    | Some (h, cx) ->
         match h.core with
          | Fresh (hint, _, kind, Unbounded)
          ->
              let kind_str = match kind with
                | Constant -> "CONSTANT"
                | State -> "STATE"
                | Action -> "ACTION"
                | Temporal -> "TEMPORAL"
                | Unknown -> "Unknown" in
              Stack.push stack (Identhyp (kind_str, hint.core), ref false);
              spin stack cx;
              let (v, r) = Stack.pop stack in
              if !r then
                bprintf buf "%s" (kind_str ^ hint.core)
          | Fresh (hint, _, _, Bounded (_, Hidden))
          | Defn ({core = Recursive (hint, _)}, _, _, _)
          ->  Stack.push stack (Identhyp ("CON", hint.core), ref false);
              spin stack cx;
              ignore (Stack.pop stack)
          | Flex hint
          ->  Stack.push stack (Identhyp ("VAR", hint.core), ref false);
              spin stack cx;
              ignore (Stack.pop stack)
          | Defn ({core = Operator (hint, e)}, _, Hidden, _) ->
             Stack.push stack (Identhyp ("HYP", hint.core), ref false);
             spin stack cx;
             let v,r = Stack.pop stack in
             if !r then
               bprintf buf "$Def(%d,%d)"
                       (match v with Identhypi i -> i | _ -> assert false)
                       (if Expr.Constness.is_const e then 0 else 3)
          | Defn ({core = Bpragma _}, _, Hidden, _) ->
             Stack.push stack (IdentBPragma, ref false);
             spin stack cx;
             ignore (Stack.pop stack)
          | Defn ({core = Instance _}, _, Hidden, _) -> assert false
          | Fact (_, Hidden, _) ->
              (* These include pragmas mentioned in the `BY` and made hidden
              by the function `Backend.Prep.find_meth`. The function
              `Backend.Prep.find_meth` has been changed to keep these facts
              visible, so that proofs with identical assertions and different
              `BY` statements would correspond to different fingerprints.
              *)
              (* Util.printf ~prefix:"[DEBUG]: " "Hidden `Fact`"; *)
              Stack.push stack (No(*Identvar "HIDDENFACT"*), ref false);
              spin stack cx ;
              ignore (Stack.pop stack)

          | Fresh (hint, _, _, Bounded (e, Visible)) ->
              Stack.push stack (Identhyp ("CON", hint.core), ref false);
              spin stack cx;
              let v,r = Stack.pop stack in
                if !r then bprintf buf "$Dom(%d;%a)"
                  (match v with Identhypi i -> i | _ -> assert false)
                  (fp_expr counthyp countvar stack) e
                else
                  bprintf buf "$Dom(_;%a)" (fp_expr counthyp countvar stack) e
                    (* bug 13-12-07 : must not suppress assumptions of the
                       form "x \in S" even if x is not used. *)
          | Defn ({core = Operator (hint, e)}, _, Visible, _) ->
             Stack.push stack (Identhyp ("HYP", hint.core), ref false);
              spin stack cx;
              let v,r = Stack.pop stack in
                if !r then
                  bprintf buf "$Def(%d;%a)"
                          (match v with Identhypi i -> i | _ -> assert false)
                          (fp_expr counthyp countvar stack) e
          | Defn ({core = Bpragma _}, _, Visible, _) ->
             Stack.push stack (IdentBPragma, ref false);
             spin stack cx;
             ignore (Stack.pop stack)
          | Defn ({core = Instance _}, _, Visible, _) -> assert false
          | Fact (e, Visible, tm) ->
               Stack.push stack (Identhyp ("HYP", "None"), ref false);
              spin stack cx;
              ignore (Stack.pop stack);
              (*
              Util.printf ~prefix:"[DEBUG]: " "Visible `Fact` ";
              let msg = "expr:\n" in
              let pr_obl fmt = ignore (
                  let print = Expr.Fmt.pp_print_expr in
                  let cx = (Deque.empty, Ctx.dot) in
                  let fmt = Format.std_formatter in
                  print cx fmt e)
              in Util.printf ~at:e ~prefix:"[DEBUG]: "
                "%s@\n  @[<b0>%t@]@." msg pr_obl;
              *)
              bprintf buf "$Fact(%a,%s)" (fp_expr counthyp countvar stack) e
                      (time_to_string tm);
  in
  spin stack sq.context

and fp_let counthyp countvar stack buf ds e =
  let rec spin stack = function
    | [] -> fp_expr counthyp countvar stack buf e
    | d :: ds -> begin match d.core with
        | Operator (hint, e)
        | Bpragma (hint, e, _) ->
            fp_expr counthyp countvar stack buf e ;
            Buffer.add_char buf '.' ;
            Stack.push stack (Identvar hint.core, ref false);
            spin stack ds;
            ignore(Stack.pop stack)
        | Instance _ ->
            Errors.bug ~at:d "Backend.Fingerprints.fp_let: INSTANCE 3"
        | _ ->
            Errors.bug ~at:d "Backend.Fingerprints.fp_let: other"
      end
  in
  spin stack ds

and fp_bounds counthyp countvar stack vars = function
  | [] -> ""
  | (hint, _, bd) :: bs ->
      let res = begin match bd with
        | Domain d ->
             Printf.sprintf "%d:%s,"
               (match (List.hd vars) with Identvari i,_ -> i
                  | Identvar _ ,_ -> 0
                  | _ -> assert false)
               (let b = Buffer.create 17 in fp_expr counthyp countvar stack b d; Buffer.contents b) ;
        | _ -> ""
      end in
      res^(fp_bounds counthyp countvar stack (List.tl vars) bs)

and fp_field counthyp countvar stack buf (fld, e) =
  bprintf buf "(%s,%a)" fld (fp_expr counthyp countvar stack) e

and fp_exspec counthyp countvar stack buf (trail, e) =
  bprintf buf "(%a=%a)"
    (list ~sep:(fun _ -> ()) (fp_expoint counthyp countvar stack)) trail
    (fp_expr counthyp countvar stack) e

and fp_expoint counthyp countvar stack buf = function
  | Except_dot s ->
      bprintf buf ".%s" s
  | Except_apply e ->
      bprintf buf ".%a" (fp_expr counthyp countvar stack) e

and fp_arm counthyp countvar stack buf (p, e) =
  bprintf buf "(%a,%a)" (fp_expr counthyp countvar stack) p (fp_expr counthyp countvar stack) e

let print_fp sq buf =
    (* Print the buffer contents, which are the string from which the
    fingerprint is computed.
    *)
    print_string "\nExpression:\n";
    let cx = Deque.empty in
    print_string (Expr.Fmt.string_of_expr cx (noprops (Sequent sq)) );
    print_string "\nString used to create fingerprint:\n";
    Buffer.output_buffer stdout buf;
    print_string "\nEnd of string used to create fingerprint\n\n"

let fp_sequent sq =
  let buf = Buffer.create 17 in
  fp_sequent (Stack.create 5 (No, ref false)) buf sq ;
  (* print_fp sq buf; *)
  buf


let fingerprint ob =
 to_string (fp_sequent ob.Proof.T.obl.core)

(* adds its fingerprint to an obligation *)
let write_fingerprint ob =
{ob with fingerprint = Some (fingerprint ob)}
