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

(** Defines a Michelson expression representation as a Micheline node with
    canonical ([int]) location and [Michelson_v1_primitives.prim] as content.

    Types [expr] and [node] both define representation of Michelson
    expressions and are indeed the same type internally, although this is not
    visible outside Micheline due to interface abstraction. *)

(** Locations are used by Micheline mostly for error-reporting and pretty-
    printing expressions. [canonical_location] is simply an [int]. *)
type location = Micheline.canonical_location

(** Annotations attached to Michelson expressions. *)
type annot = Micheline.annot

(** Represents a Michelson expression as canonical Micheline. *)
type expr = Michelson_v1_primitives.prim Micheline.canonical

type error += Lazy_script_decode (* `Permanent *)

(** A record containing either an underlying serialized representation of an
    expression or a deserialized one, or both. If either is absent, it will be
    computed on-demand. *)
type lazy_expr = expr Data_encoding.lazy_t

(** Same as [expr], but used in different contexts, as required by Micheline's
    abstract interface. *)
type node = (location, Michelson_v1_primitives.prim) Micheline.node

val location_encoding : location Data_encoding.t

val expr_encoding : expr Data_encoding.t

val lazy_expr_encoding : lazy_expr Data_encoding.t

val lazy_expr : expr -> lazy_expr

(** Type [t] joins the contract's code and storage in a single record. *)
type t = {code : lazy_expr; storage : lazy_expr}

val encoding : t Data_encoding.encoding

(* Basic gas costs of operations related to processing Michelson: *)

val deserialization_cost_estimated_from_bytes : int -> Gas_limit_repr.cost

val deserialized_cost : expr -> Gas_limit_repr.cost

val serialized_cost : bytes -> Gas_limit_repr.cost

val bytes_node_cost : bytes -> Gas_limit_repr.cost

val force_decode_cost : lazy_expr -> Gas_limit_repr.cost

val force_decode : lazy_expr -> expr tzresult

val force_bytes_cost : lazy_expr -> Gas_limit_repr.cost

val force_bytes : lazy_expr -> bytes tzresult

val unit_parameter : lazy_expr

val is_unit_parameter : lazy_expr -> bool

val strip_annotations : node -> node

val strip_locations_cost : node -> Gas_limit_repr.cost

module Micheline_size : sig
  type t = {
    nodes : Saturation_repr.may_saturate Saturation_repr.t;
    string_bytes : Saturation_repr.may_saturate Saturation_repr.t;
    z_bytes : Saturation_repr.may_saturate Saturation_repr.t;
  }

  val of_node : node -> t
end

(** [micheline_nodes root] returns the number of internal nodes in the
   micheline expression held from [root]. *)
val micheline_nodes : node -> int

(** [node_size root] returns the size of the in-memory representation
   of [root] in bytes. This is an over-approximation of the memory
   actually consumed by [root] since no sharing is taken into
   account. *)
val node_size : node -> int
