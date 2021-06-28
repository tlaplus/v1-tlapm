(*
 * tlapm.ml --- driver
 *
 *
 * Copyright (C) 2008-2010  INRIA and Microsoft Corporation
 *)

open Ext
open Property
open Util.Coll

module P = Tla_parser.P

open Proof.T

open Module.T

module Clocks = struct
  include Timing

  let parsing = new_clock "parsing"
  let print   = new_clock "formatting"
  let elab    = new_clock "analysis"
  let gen     = new_clock "generation"
  let prep    = new_clock "simplification"
  let backend = new_clock "interaction"
  let check   = new_clock "checking"
  let fp_loading = new_clock "fp_loading"
  let fp_saving = new_clock "fp_saving"
  let fp_compute = new_clock "fp_compute"


  let pad_left md str = Printf.sprintf "%*s" md str

  let report () =
    let clocks =
      [ total "total"; parsing; elab; gen; prep; print; backend; check;
        fp_loading; fp_saving; fp_compute; ambient ]
    in
    let max_desc_width =
      List.fold_left (fun mx cl -> max mx (String.length cl.desc)) 0 clocks
    in
    let clocks =
      List.map (fun cl -> {cl with desc = pad_left max_desc_width cl.desc})
               clocks
    in
    Util.printf "(* %s | time (seconds) *)"
                (pad_left max_desc_width "operation");
    Util.printf "(* %s-+--------------- *)" (String.make max_desc_width '-');
    List.iter begin
      fun cl -> Util.printf "(* %s  *)%!" (string_of_clock cl)
    end (List.tl clocks);
    Util.printf "(* %s-+--------------- *)" (String.make max_desc_width '-');
    Util.printf "(* %s  *)" (string_of_clock (List.hd clocks));

end


let mkdir_tlaps t =
    let cachedir = ".tlacache" in
    let tlapsdir = cachedir ^ "/" ^ t.core.name.core ^ ".tlaps" in
    if not (Sys.file_exists cachedir) then Unix.mkdir cachedir 0o777;
    if not (Sys.file_exists tlapsdir) then Unix.mkdir tlapsdir 0o777;
    (cachedir, tlapsdir)


let handle_abort _ =
  if !Params.verbose then
    Util.eprintf ~prefix:"FATAL: " ">>> Interrupted -- aborting <<<" ;
  if !Params.stats then
    Clocks.report () ;
  Stdlib.exit 255


module IntSet = Set.Make (struct type t = int let compare = (-) end);;

let modules_list : string list ref = ref []


let print_proved_obligation (ob: Proof.T.obligation) =
    if !Params.verbose then
        Util.printf
            ~at:ob.Proof.T.obl
            ~prefix:"[INFO]: "
            "@[<v2>Attempted to prove or check:@,%a@]@."
            Proof.Fmt.pp_print_obligation ob


let print_proved_obligations
        (proved: Proof.T.obligation list ref)
        (obs: Proof.T.obligation array)
        (tla_module: Module.T.mule): unit =
    List.iter print_proved_obligation !proved


let print_unproved_obligation (ob: Proof.T.obligation) =
    Util.eprintf
        ~at:ob.Proof.T.obl
        ~prefix:"[ERROR]: "
        "@[<v2>Could not prove or check:@,%a@]@."
        Proof.Fmt.pp_print_obligation ob


let print_unproved_obligations
        (unproved: Proof.T.obligation list ref)
        (obs: Proof.T.obligation array)
        (tla_module: Module.T.mule): unit =
    List.iter print_unproved_obligation !unproved;
    let n_unproved = List.length !unproved in
    let n_obligations = Array.length obs in
    let s = if n_obligations > 1 then "s" else "" in
    let n_neg = string_of_int n_unproved in
    let n_all = string_of_int n_obligations in
    if n_unproved <> 0 then begin
        Util.eprintf
            ~at:tla_module "%s"
            ~prefix:"[ERROR]: "
            (n_neg ^ "/" ^ n_all ^ " obligation" ^ s ^ " failed.");
        Util.eprintf
            "There were backend errors processing module `%S`."
            tla_module.core.name.core;
        if not !Params.toolbox then
            failwith "backend errors: there are unproved obligations"
    end else begin
        Util.eprintf
            ~at:tla_module "%s"
            ~prefix:"[INFO]: "
            ("All " ^ n_all ^ " obligation" ^ s ^ " proved.")
    end


(* Note that when process_obs is called, all obligations have id fields *)
let process_obs
        (t: Module.T.mule)
        (obs: Proof.T.obligation array)
        (modname: string)
        (thyf: string)
        (fpf: string):
            unit =
    (* initialize table of treated obligations *)
    let treated = ref IntSet.empty in
    (* initialize table of proved obligations *)
    let proved_ids = ref IntSet.empty in
    let record
            (success: bool)
            (ob: Proof.T.obligation):
                unit =
        (* the number `obl_id \in Nat` that identifies the obligation `ob` *)
        let obl_id = Option.get ob.id in
        (* store the obligation id number in the internal table `treated` *)
        treated := IntSet.add obl_id !treated;
        (* if the prover (frontend or backend) succeeded, *)
        if success then (* then store the obligation id number in
                        the internal table `proved_ids`
                        *)
            proved_ids := IntSet.add obl_id !proved_ids;
        in
    let collect_untreated_obligations
            (untreated: Proof.T.obligation list ref):
                unit =
        (* Store in the `list ref` `untreated` all the obligations that
        are not in the `IntSet` `treated`.
        *)
        let f ob =
            let obl_id = Option.get ob.id in
            if not (IntSet.mem obl_id !treated) then
                untreated := ob :: !untreated;
            in
        Array.iter f obs
        in
    let collect_proved_obligations
            (proved: Proof.T.obligation list ref):
                unit =
        let f ob = begin
            let obl_id = Option.get ob.id in
            if (IntSet.mem obl_id !proved_ids) then
                proved := ob :: !proved
            end
            in
        Array.iter f obs
        in
    let collect_unproved_obligations
            (unproved: Proof.T.obligation list ref):
                unit =
        let f ob = begin
            let obl_id = Option.get ob.id in
            if not (IntSet.mem obl_id !proved_ids) then
                unproved := ob :: !unproved
            end
            in
        Array.iter f obs
        in
    Clocks.start Clocks.backend ;
    (* initialize file for output of fingerprints
    (saves fingerprints file history)
    *)
    let fpout = Fpfile.fp_init fpf !modules_list in
    let thyout = Isabelle.thy_init modname thyf in
    let _ = Errors.get_warnings () in
    (* prepare proof tasks *)
    let tasks =
        try
            let f = Prep.make_task fpout thyout record in
            Array.to_list (Array.map f obs)
        with Exit -> []
    in
    (* proving *)
    Schedule.run !Params.max_threads tasks;
    Isabelle.thy_close thyf thyout;
    (* close fingerprints file *)
    Fpfile.fp_close_and_consolidate fpf fpout;
    Clocks.stop ();
    (* `--noproving` command line option or TLA+ Toolbox has sent "stop" *)
    if not (!Params.noproving || (Toolbox.is_stopped ())) then begin
    (* Check proof results for each obligation, output summary *)
    if !Params.toolbox then begin
        let untreated = ref [] in
        collect_untreated_obligations untreated;
        let result =
            let c = Types.Cantwork "unexpected error" in
            let fail = Types.RFail (Some c) in
            Types.NTriv (fail, Method.Fail)
            in
        let f ob =
            Toolbox.print_new_res ob result "" None
            in
        List.iter f !untreated
        end;
    (* Printing of proved and unproved obligations *)
    let proved = ref [] in
    let unproved = ref [] in
    collect_proved_obligations proved;
    collect_unproved_obligations unproved;
    print_proved_obligations proved obs t;
    print_unproved_obligations unproved obs t
    end


let add_id i ob = {ob with id = Some (i+1)}


let toolbox_consider ob =
    let loc = Option.get (Util.query_locus ob.Proof.T.obl) in
    !Params.tb_sl <= Loc.line loc.Loc.start
    && Loc.line loc.Loc.stop <= !Params.tb_el

let toolbox_clean arr =
    if !Params.toolbox
        then List.filter toolbox_consider (Array.to_list arr)
        else Array.to_list arr


let process_module
        mcx
        (t: Module.T.mule) =
    modules_list := t.core.name.core :: !modules_list;
    if t.core.important then begin
        let (_, tlapsdir) = mkdir_tlaps t in
        Params.output_dir := tlapsdir;
    end;
    (* names of theory and fingerprint files *)
    (* Theory file name *)
    let thyf: string = Filename.concat
                            !Params.output_dir (t.core.name.core ^ ".thy")
    (* Fingerprints output file name *)
    and fpf: string = Filename.concat
                            !Params.output_dir "fingerprints"
    in
    (* file for output of fingerprints *)
    (Params.fpf_out: string option ref) := Some fpf;
    (* cases of module (stage: Module.T.stage) =
        | Special
        | Final _
        | Parsed | Flat
    *)
    let (mcx, t) = match t.core.stage with
    | Special -> (mcx, t)
    | Final _ ->
        if Params.debugging "rep" && t.core.important then begin
            Clocks.start Clocks.print ;
            Module.Fmt.pp_print_module
                (Deque.empty, Ctx.dot) Format.std_formatter t ;
            Format.printf "\n%!" ;
            Clocks.stop () ;
        end ;
        (mcx, t)
    | _ ->
        if !Params.verbose then begin
            Util.printf "(* processing module %S *)" t.core.name.core
        end ;
        Clocks.start Clocks.elab ;
        (* Normalize the proofs in order to get proof obligations *)
        let (mcx, t, summ) = Module.Elab.normalize mcx Deque.empty t in
        (*
        List.iter
            (fun u -> Module.Fmt.pp_print_module
                (Deque.empty, Ctx.dot) Format.std_formatter (snd u))
            (Sm.bindings mcx);
        *)
        (*
        let _ = Sm.iter
                    (fun f u -> Printf.printf "Module: %s\n" u.core.name.core)
                    mcx in
        *)
        Clocks.stop () ;
        if Params.debugging "rep" && t.core.important then begin
            Clocks.start Clocks.print ;
            Module.Fmt.pp_print_module
                (Deque.empty, Ctx.dot)
                Format.std_formatter t ;
            Format.printf "\n%!" ;
            Clocks.stop () ;
        end ;
        if !Params.stats && t.core.important then begin
            Util.printf
                "(* module %S: %d total %s *)"
                t.core.name.core
                summ.sum_total
                (Util.plural summ.sum_total "obligation")
        end ;

        (* managing the fingerprints (erasing or loading) *)
        (* `--cleanfp` command line option *)
        if !Params.cleanfp && t.core.important then begin
            try
                Sys.remove fpf;
                Util.printf "(* fingerprints file %S removed *)%!" fpf
            with _ ->
                if Sys.file_exists fpf then
                    Util.printf "%s%s" (
                        "(* did not succeed in removing " ^
                        "fingerprints file %S *)%!") fpf
        end
        else begin
            (* file for input of fingerprints *)
            let fpf_in = begin
                match !Params.fpf_in with
                    | Some f -> f  (* `--usefp` command line option *)
                    | None -> fpf  (* same as file for output of fingerprints *)
            end in
            if      Sys.file_exists fpf_in
                    && (summ.sum_total <> 0)
                    && t.core.important
                then begin
                Util.printf "(* loading fingerprints in %S *)%!" fpf_in;
                Clocks.start Clocks.fp_loading;
                (* load fingerprints from input file *)
                Backend.Fpfile.load_fingerprints fpf_in;
                Params.fp_loaded := true;
                Params.fp_original_number := Backend.Fpfile.get_length ();
                Clocks.stop ()
             end
        end;

        flush stdout ;
        Clocks.start Clocks.prep ;
        let fin = match t.core.stage with
            | Final fin -> fin
            | _ -> Errors.bug ~at:t
                        "normalization didn't produce a finalized module"
        in
        let obs = Array.mapi add_id fin.final_obs in  (* add obligation ids *)
        let obs = toolbox_clean obs in (* only consider specified obligations *)
        let fin = {
                fin with final_obs = Array.of_list obs ;
                final_status = (Incomplete, summ) } in
        t.core.stage <- Final fin ;
        Module.Save.store_module ~clock:Clocks.elab t ;
        (mcx, t)
    in
    if !Params.summary && t.core.important then
        Module.Fmt.summary t ;
    begin match t.core.stage with
    | Final fin when t.core.important
        (* Array.length fin.final_obs > 0 *)
        ->
        if !Params.verbose then
            Util.printf "(* module %S: %d unique obligations *)"
                t.core.name.core
                (Array.length fin.final_obs) ;

        if (!Params.toolbox) then begin
            let f ob =
                Backend.Toolbox.toolbox_print
                    ob
                    "to be proved"
                    None
                    None
                    0.
                    None
                    !Params.printallobs None "" None
            in
            (* prints the list of obligations which have to be proved *)
            Array.iter f fin.final_obs;
            (* prints total number of obligations *)
            Backend.Toolbox.print_ob_number
                (Array.length fin.final_obs) ;
        end;

        let missing =
            match fin.final_status with
            | (Incomplete, miss) -> snd (miss.sum_absent)
            | _ -> []
        in

        begin
        if not !Params.suppress_all then
            process_obs t fin.final_obs
            t.core.name.core thyf fpf;

        (** Added by HV. It collects all facts and definitions used in the
        current proof tree into a one-line proof. *)
        if Params.debugging "oneline" && t.core.important then begin
            Util.eprintf "One-line proof:\n";
            match Module.Gen.collect_usables t with
                | None -> Util.eprintf "  OBVIOUS"
                | Some u ->
                    let s = Util.sprintf "@[<hov2>%a@]"
                        (Proof.Fmt.pp_print_usable (Deque.empty,Ctx.dot)) u in
                    let s = Str.global_replace (Str.regexp "?") "" s in
                        Util.eprintf "  BY @[<hov2>%s@]@.\n" s
        end else ();

        let wrap x = { core = x; props = [] } in
        let dummy_seq = {
            Expr.T.context = Deque.empty;
            Expr.T.active = wrap (Expr.T.String "");
            } in
        let dummy_ob: Proof.T.obligation = {
                id = None;
                obl = wrap dummy_seq;
                fingerprint = None;
                kind = Ob_main;
            } in
        Array.fill fin.final_obs 0 (Array.length fin.final_obs) dummy_ob;

        if t.core.important && not (Toolbox.is_stopped ()) then begin
            Clocks.start Clocks.check ;
            let modname = t.core.name.core in
            let nmiss = List.length missing in
            if !Params.check then
                Std.finally Clocks.stop Isabelle.recheck (modname, nmiss, thyf)
        end;
        Clocks.stop ();
        (mcx, t)
        end
    | _ -> (mcx, t)
    end

let read_new_modules mcx fs =
  (* Read the files with names in the list of strings `fs`. *)
  List.fold_left begin
    fun (mcx, mods) fn ->
      let mule =
        Module.Save.parse_file ~clock:Clocks.parsing
                               (Util.locate fn Loc.unknown)
      in
      (* set a flag for each module of the new modules that it is important *)
      mule.core.important <- true ;
      let mcx = Sm.add mule.core.name.core mule mcx in
      (* `mcx` is a mapping from names of already loaded modules and
      modules loaded by the function `read_new_modules`, to modules
      (values of type `mule`)

      `mods` is a list of module (values of type `mule`) that are loaded by
      the function `read_new_modules`.
      *)
      (mcx, mule :: mods)
  end (mcx, []) fs

let print_modules mcx =
    print_string "\nModules loaded so far:\n";
    Sm.iter (fun name mule -> Printf.printf "Module name: \"%s\"\n" name) mcx

let main fs =
  Params.input_files := List.map Filename.basename fs;
  let () =
    List.iter begin
      fun s ->
        ignore (Sys.signal s (Sys.Signal_handle handle_abort))
    end [Sys.sigint ; Sys.sigabrt ; Sys.sigterm] in
  let () = Format.pp_set_max_indent Format.std_formatter 2_000_000 in
  let mcx = Module.Standard.initctx in
  (* reads the new modules and return both the map:name->module with the new
   * module and a list of the new modules*)
  (* The module names (or file names) in the list `fs` are those listed on
  the command line. Each file is read by the function `read_new_modules .
  Submodules are read below.
  *)
  let (mcx, mods) = read_new_modules mcx fs in
  (* print_modules mcx; *)
  if List.length mods = 0 then begin
    Util.eprintf ~prefix:"FATAL: " "could not read any modules successfully!" ;
    failwith "fatal error: could not read any modules";
  end else begin
    (* load the transitive closure over extends of all modules *)
    (* TODO: load also modules that occur in `INSTANCE` statements from extended modules. *)
    let mcx = Module.Save.complete_load ~clock:Clocks.parsing mcx in
    (* flatten the modules *)
    let (mcx, mods) = Module.Dep.schedule mcx in
      let f mcx m =
        (* processing the proofs in the commandline modules *)
        let (mcx, m) = process_module mcx m in
        Sm.add m.core.name.core m mcx
      in
      ignore (List.fold_left f mcx mods)
  end ;
  if !Params.stats then Clocks.report ()


let init () =
  Random.self_init();
  Printexc.record_backtrace true;
  Format.pp_set_max_indent Format.err_formatter 35;
  if Config.debug then
    main (Tlapm_args.init ())
  else
    try main (Tlapm_args.init ()) with
    | Errors.Fatal ->
       Util.eprintf "tlapm: Exiting because of the above error.";
       exit 0;
    | e ->
       let backtrace = Printexc.get_backtrace () in
       Format.pp_print_flush Format.std_formatter ();
       Format.pp_print_flush Format.err_formatter ();
       Stdlib.flush stdout;
       Stdlib.flush stderr;
       let error = (Printexc.to_string e) ^ "\n" ^ backtrace in
       Util.eprintf ~prefix:"FATAL:" " tlapm ending abnormally with %s" error;
       let config = Params.print_config_toolbox false in
       begin match !Errors.loc, !Errors.msg with
       | Some l, Some m -> Backend.Toolbox.print_message (l ^  "\n\n" ^ m)
       | None, Some m -> Backend.Toolbox.print_message m
       | _, _ ->
          let msg =
            Printf.sprintf
               "Oops, this seems to be a bug in TLAPM.\n\
                Please give feedback to developers.\n\n\n %s\n%s"
               error config
          in
          let url = "http://tla.msr-inria.inria.fr/bugs" in
          Backend.Toolbox.print_message_url msg url;
       end;
       exit 3;
;;

exception Stacktrace;;

Sys.set_signal Sys.sigusr1 (Sys.Signal_handle (fun _ -> raise Stacktrace));;

init ();;
