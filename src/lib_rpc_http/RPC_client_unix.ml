(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

type attempt_event = {attempt : int; delay : float; text : string}

module Attempt_logging = Internal_event.Make (struct
  type t = attempt_event

  let name = "rpc_http_attempt"

  let doc = "Error emitted when an HTTP request returned a 502 error."

  let encoding =
    Data_encoding.(
      conv
        (fun {attempt; delay; text} -> (attempt, delay, text))
        (fun (attempt, delay, text) -> {attempt; delay; text})
        (obj3 (req "attempt" int8) (req "delay" float) (req "text" string)))

  let pp f {attempt; delay; text} =
    Format.fprintf
      f
      "Attempt number %d/10, will retry after %g seconds.\n\
       Original body follows.\n\
       %s"
      attempt
      delay
      text

  let level _ = Internal_event.Error
end)

include RPC_client.Make (struct
  include Cohttp_lwt_unix.Client

  let clone_body = function
    | `Stream s ->
        `Stream (Lwt_stream.clone s)
    | x ->
        x

  let call ?ctx ?headers ?body ?chunked meth uri =
    let rec call_and_retry_on_502 attempt delay =
      call ?ctx ?headers ?body ?chunked meth uri
      >>= fun (response, ansbody) ->
      let status = Cohttp.Response.status response in
      match status with
      | `Bad_gateway ->
          let log_ansbody = clone_body ansbody in
          Cohttp_lwt.Body.to_string log_ansbody
          >>= fun text ->
          Attempt_logging.emit (fun () -> {attempt; delay; text})
          >>= fun _ ->
          if attempt >= 10 then Lwt.return (response, ansbody)
          else
            Lwt_unix.sleep delay
            >>= fun () -> call_and_retry_on_502 (attempt + 1) (delay +. 0.1)
      | _ ->
          Lwt.return (response, ansbody)
    in
    call_and_retry_on_502 1 0.
end)
