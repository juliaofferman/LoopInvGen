open Core
open Core.Out_channel
open SyGuS
open Utils

let checkInvariant (inv : string) ~(sygus : SyGuS.t) : bool =
  let open ZProc in
  let z3 = create ()
   in Simulator.setup sygus z3
    ; ignore (run_queries ~local:false z3 []
                ~db:[("(define-fun invf ("
                    ^ (List.to_string_map sygus.inv_vars ~sep:" "
                          ~f:(fun (s, t) -> "(" ^ s ^ " " ^
                                            (Types.string_of_typ t) ^ ")"))
                    ^ ") Bool " ^ inv ^ ")")])
    ; let result =
        match [ (implication_counter_example z3 sygus.pre.expr inv)
              ; (implication_counter_example z3
                   ("(and " ^ sygus.trans.expr ^ " " ^ "(invf "
                   ^ (List.to_string_map sygus.inv_vars ~sep:" " ~f:fst)
                   ^ "))")
                   ("(invf "
                   ^ (List.to_string_map sygus.inv_vars ~sep:" "
                                         ~f:(fun (s, _) -> s ^ "!"))
                   ^ ")"))
              ; (implication_counter_example z3 inv sygus.post.expr) ]
        with [ None ; None ; None ] -> true | _ -> false
      in ZProc.close z3 ; result

let main invfile do_log filename () =
  (if do_log then Log.enable ~msg:"VERIFIER" () else ()) ;
  let in_chan = Utils.get_in_channel invfile in
  let inv = String.concat (In_channel.input_lines in_chan) ~sep:" "
  in In_channel.close in_chan
   ; let sygus = SyGuS.load (Utils.get_in_channel filename)
     in Out_channel.output_string stdout (
          if checkInvariant inv ~sygus then "PASS\n" else "FAIL\n")

let cmd =
  Command.basic
    ~summary: "Check sufficiency of a generated invariant for proving correctness."
    Command.Spec.(
      empty
      +> flag "-i" (required string)  ~doc:"FILENAME invariant file"
      +> flag "-l" (no_arg)           ~doc:"enable logging"
      +> anon (maybe_with_default "-" ("filename" %: file))
    )
    main

let () =
  Command.run
    ~version:"0.6b"
    ~build_info:("padhi @ " ^ (Core_extended.Logger.timestamp ()))
    cmd