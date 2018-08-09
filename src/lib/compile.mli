(** Compilers of the {!EDSL.t} values. *)

(** {3 Pretty-printing Output} *)

val pp_hum : Format.formatter -> 'a EDSL.t -> unit
(** Pretty print a Genspio expression with the {!Format} module. *)

val to_string_hum : 'a EDSL.t -> string
(** Pretty print a Genspio expression to [string]. *)

val to_one_line_hum : 'a EDSL.t -> string
(** Like [to_string_hum] but avoiding new-lines. *)

(** {3 Compilation to POSIX Shell Scripts} *)

(** Compiler from {!EDSL.t} to POSIX shell scripts. *)
module To_posix : sig
  (** When a compiled script runs into an error, these details are
      accessible to the user.  *)
  type internal_error_details = Language.internal_error_details =
    { variable: string
          (** The incriminated issue was stored in a shell variable. *)
    ; content: string  (** The shell-code that produced the [variable]. *)
    ; code: string  (** Pretty-printed version of the above EDSL code. *) }

  (** The kinds of messages that can be output or stored before
      exiting a script. *)
  type death_message = Language.death_message =
    | User of string
        (** The argument of the {!EDSL.fail} is the “user” case. *)
    | C_string_failure of internal_error_details
        (** The checking that a byte-array {i is} a C-String can fail when
        the byte-array contains ['\x00']. *)
    | String_to_int_failure of internal_error_details
        (** {!string_to_int} can obviously fail.*)

  (** When failing (either with {!EDSL.fail} or because of internal
      reasons) the compiler uses a customizable function to output the “error”
      message and then quiting the process. *)
  type death_function = comment_stack:string list -> death_message -> string

  (** The potential compilation error. *)
  type compilation_error = Language.compilation_error =
    { error:
        [ `No_fail_configured of death_message
          (** Argument of the
                                                 {!death_function}. *)
        | `Max_argument_length of string  (** Incriminated argument. *)
        | `Not_a_c_string of string  (** The actual problematic string. *) ]
          (** Error description. *)
    ; code: string option  (** Chunk of relevant, pretty-printed EDSL code. *)
    ; comment_backtrace: string list
          (** Stack of `Comment` constructs at the point of the error. *) }

  val pp_error : Format.formatter -> compilation_error -> unit
  (** Printer for error values. *)

  val error_to_string : compilation_error -> string
  (** Convenience display of error values. *)

  (** Configuration of the compilation to POSIX shell scripts. *)
  type parameters =
    { style: [`Multi_line | `One_liner]
          (** The kind of script to output: in one-liners sequences are
        separated with [";"], in multi-line scripts, sequences are
        separated with new lines. *)
    ; max_argument_length: int option
          (** A limit on the length of the literal command line arguments
        generated by the compiler.

        - [None] means “do not check.”
        - The default value for is [Some 100_000], meaning that ≥
          100 000 B arguments will make the compiler fail with an
          exception.  *)
    ; fail_with: [`Kill of string | `Nothing | `Trap_and_kill of int * string]
          (** How to implement the [EDSL.fail] construct (which appears also
        internally e.g. when {!EDSL.to_c_string} fails.).

        - [`Nothing]: the compiler will fail to compile [fail] constructs.
        - [`Kill signal_name]: the compiler will store the “toplevel”
          process id of the script and {!EDSL.fail} will be trying to
          kill the script with the signal [signal_name]
          (e.g. ["USR2"]).
        - [`Trap_and_kill (exit_status, signal_name)]: the
          {!EDSL.fail} construct will kill the script with
          [signal_name] {b and} the signal will be caught with the
          POSIX ["trap"] command in order to exit with [exit_status].
    *)
    ; print_failure: death_function
          (** How to deal with the {!death_message} in case of failure.
        The function should return a shell command, like the result of
        compiling a [unit EDSL.t] expression or what {!Sys.command}
        can work with. *)
    }

  val failure_to_stderr : death_function
  (** The default {!death_function} just prints to [stderr]. *)

  val one_liner : parameters
  (** The default parameters for one-liners: {[
        {
          style = `One_liner;
          max_argument_length = Some 100_000;
          fail_with = `Trap_and_kill (78, "USR2");
          print_failure = failure_to_stderr;
        }]} *)

  val multi_line : parameters
  (** The default parameters for multi-liners (similar to {!one_liner}). *)

  val default_options : parameters
  (** The default value for [?option] in {!string}, which is {!one_liner}. *)

  val string :
    ?options:parameters -> 'a EDSL.t -> (string, compilation_error) result
  (** Compile a Genspio expression to a POSIX shell “phrase”
      (one-liner or multi-line) according to the [?options] (see
      {!parameters}).
  *)
end

(** The much slower but more portable compiler. *)
module To_slow_flow : sig
  module Script : sig
    type t

    val pp : Format.formatter -> t -> unit
  end

  val compile :
       ?tmp_dir_path:[`Fresh | `Use of string]
    -> ?signal_name:string
    -> ?trap:[`Exit_with of int | `None]
    -> 'a EDSL.t
    -> Script.t
end


(** {3 Legacy API}

These functions are here for backwards compatibility, please use now
the {!To_posix} module.

*)

val default_max_argument_length : int option
(** See argument [?max_argument_length] of {!to_one_liner}. *)

val to_one_liner :
  ?max_argument_length:int option -> ?no_trap:bool -> 'a EDSL.t -> string
(** Compile a Genspio expression to a single-line POSIX shell command.

    The shell command starts by using ["trap"] to allow the script to
    abort thorugh the {!EDSL.fail} construct; one can avoid this setup
    with [~no_trap:true]

    If [~no_trap:true] is used and the script used the {!EDSL.fail}
    construct, [to_one_liner] fails with an exception.
    {[
       utop # Genspio.Compile.to_one_liner ~no_trap:true Genspio.EDSL.(seq [ eprintf (string "Hello\\n") []; fail ]);;
       Exception: Failure
       "Die command not set: you cannot use the `fail` construct together with the `~no_trap:true` option (error message was: \"EDSL.fail called\")".
    ]}
    
    The default value for [max_argument_length] is
    {!default_max_argument_length} ([Some 100_000]); it is a limit on
    the length of the literal command line arguments generated by the compiler.
    [None] means “do not check.”

    If the compilation fails, the function raises an [Failure]
    exception containing the error message.
*)

val to_many_lines :
  ?max_argument_length:int option -> ?no_trap:bool -> 'a EDSL.t -> string
(** Compile a Genspio expression to a multi-line POSIX shell script,
    slightly more readable than {!to_one_liner}.
*)

val quick_run_exn :
  ?max_argument_length:int option -> ?no_trap:bool -> 'a EDSL.t -> unit
(** Compile an expression and use [Sys.command] on it; if the overall
    command does not return 0 an exception is raised. *)
