(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2020 Metastate AG <hello@metastate.dev>                     *)
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

open Alpha_context
open Script_int

(* Preliminary definitions. *)

type var_annot = Var_annot of string

type type_annot = Type_annot of string

type field_annot = Field_annot of string

type never = |

type address = Contract.t * string

type ('a, 'b) pair = 'a * 'b

type ('a, 'b) union = L of 'a | R of 'b

type operation = packed_internal_operation * Lazy_storage.diffs option

type 'a ticket = {ticketer : address; contents : 'a; amount : n num}

module type TYPE_SIZE = sig
  (* A type size represents the size of its type parameter.
     This constraint is enforced inside this module (Script_type_ir), hence there
     should be no way to construct a type size outside of it.

     It allows keeping type metadata and types non-private.

     This module is here because we want three levels of visibility over this
     code:
     - inside this submodule, we have [type 'a t = int]
     - outside of [Script_typed_ir], the ['a t] type is abstract and we have
        the invariant that whenever [x : 'a t] we have that [x] is exactly
        the size of ['a].
     - in-between (inside [Script_typed_ir] but outside the [Type_size]
        submodule), the type is abstract but we have access to unsafe
        constructors that can break the invariant.
  *)
  type 'a t

  val merge : 'a t -> 'b t -> 'a t tzresult

  (* Unsafe constructors, to be used only safely and inside this module *)

  val one : _ t

  val two : _ t

  val three : _ t

  val four : (_, _) pair option t

  val compound1 : Script.location -> _ t -> _ t tzresult

  val compound2 : Script.location -> _ t -> _ t -> _ t tzresult
end

module Type_size : TYPE_SIZE = struct
  type 'a t = int

  let one = 1

  let two = 2

  let three = 3

  let four = 4

  let merge x y =
    if Compare.Int.(x = y) then ok x
    else error @@ Script_tc_errors.Inconsistent_type_sizes (x, y)

  let of_int loc size =
    let max_size = Constants.michelson_maximum_type_size in
    if Compare.Int.(size <= max_size) then ok size
    else error (Script_tc_errors.Type_too_large (loc, max_size))

  let compound1 loc size = of_int loc (1 + size)

  let compound2 loc size1 size2 = of_int loc (1 + size1 + size2)
end

type empty_cell = EmptyCell

type end_of_stack = empty_cell * empty_cell

type 'a ty_metadata = {annot : type_annot option; size : 'a Type_size.t}

type _ comparable_ty =
  | Unit_key : unit ty_metadata -> unit comparable_ty
  | Never_key : never ty_metadata -> never comparable_ty
  | Int_key : z num ty_metadata -> z num comparable_ty
  | Nat_key : n num ty_metadata -> n num comparable_ty
  | Signature_key : signature ty_metadata -> signature comparable_ty
  | String_key : Script_string.t ty_metadata -> Script_string.t comparable_ty
  | Bytes_key : Bytes.t ty_metadata -> Bytes.t comparable_ty
  | Mutez_key : Tez.t ty_metadata -> Tez.t comparable_ty
  | Bool_key : bool ty_metadata -> bool comparable_ty
  | Key_hash_key : public_key_hash ty_metadata -> public_key_hash comparable_ty
  | Key_key : public_key ty_metadata -> public_key comparable_ty
  | Timestamp_key :
      Script_timestamp.t ty_metadata
      -> Script_timestamp.t comparable_ty
  | Chain_id_key : Chain_id.t ty_metadata -> Chain_id.t comparable_ty
  | Address_key : address ty_metadata -> address comparable_ty
  | Pair_key :
      ('a comparable_ty * field_annot option)
      * ('b comparable_ty * field_annot option)
      * ('a, 'b) pair ty_metadata
      -> ('a, 'b) pair comparable_ty
  | Union_key :
      ('a comparable_ty * field_annot option)
      * ('b comparable_ty * field_annot option)
      * ('a, 'b) union ty_metadata
      -> ('a, 'b) union comparable_ty
  | Option_key :
      'v comparable_ty * 'v option ty_metadata
      -> 'v option comparable_ty

let comparable_ty_metadata : type a. a comparable_ty -> a ty_metadata = function
  | Unit_key meta -> meta
  | Never_key meta -> meta
  | Int_key meta -> meta
  | Nat_key meta -> meta
  | Signature_key meta -> meta
  | String_key meta -> meta
  | Bytes_key meta -> meta
  | Mutez_key meta -> meta
  | Bool_key meta -> meta
  | Key_hash_key meta -> meta
  | Key_key meta -> meta
  | Timestamp_key meta -> meta
  | Chain_id_key meta -> meta
  | Address_key meta -> meta
  | Pair_key (_, _, meta) -> meta
  | Union_key (_, _, meta) -> meta
  | Option_key (_, meta) -> meta

let comparable_ty_size t = (comparable_ty_metadata t).size

let unit_key ~annot = Unit_key {annot; size = Type_size.one}

let never_key ~annot = Never_key {annot; size = Type_size.one}

let int_key ~annot = Int_key {annot; size = Type_size.one}

let nat_key ~annot = Nat_key {annot; size = Type_size.one}

let signature_key ~annot = Signature_key {annot; size = Type_size.one}

let string_key ~annot = String_key {annot; size = Type_size.one}

let bytes_key ~annot = Bytes_key {annot; size = Type_size.one}

let mutez_key ~annot = Mutez_key {annot; size = Type_size.one}

let bool_key ~annot = Bool_key {annot; size = Type_size.one}

let key_hash_key ~annot = Key_hash_key {annot; size = Type_size.one}

let key_key ~annot = Key_key {annot; size = Type_size.one}

let timestamp_key ~annot = Timestamp_key {annot; size = Type_size.one}

let chain_id_key ~annot = Chain_id_key {annot; size = Type_size.one}

let address_key ~annot = Address_key {annot; size = Type_size.one}

let pair_key loc (l, fannot_l) (r, fannot_r) ~annot =
  Type_size.compound2 loc (comparable_ty_size l) (comparable_ty_size r)
  >|? fun size -> Pair_key ((l, fannot_l), (r, fannot_r), {annot; size})

let pair_3_key loc l m r =
  pair_key loc m r ~annot:None >>? fun r -> pair_key loc l (r, None) ~annot:None

let union_key loc (l, fannot_l) (r, fannot_r) ~annot =
  Type_size.compound2 loc (comparable_ty_size l) (comparable_ty_size r)
  >|? fun size -> Union_key ((l, fannot_l), (r, fannot_r), {annot; size})

let option_key loc t ~annot =
  Type_size.compound1 loc (comparable_ty_size t) >|? fun size ->
  Option_key (t, {annot; size})

module type Boxed_set = sig
  type elt

  val elt_ty : elt comparable_ty

  module OPS : Set.S with type elt = elt

  val boxed : OPS.t

  val size : int
end

type 'elt set = (module Boxed_set with type elt = 'elt)

module type Boxed_map = sig
  type key

  type value

  val key_ty : key comparable_ty

  module OPS : Map.S with type key = key

  val boxed : value OPS.t * int
end

type ('key, 'value) map =
  (module Boxed_map with type key = 'key and type value = 'value)

module Big_map_overlay = Map.Make (struct
  type t = Script_expr_hash.t

  let compare = Script_expr_hash.compare
end)

type ('key, 'value) big_map_overlay = {
  map : ('key * 'value option) Big_map_overlay.t;
  size : int;
}

type 'elt boxed_list = {elements : 'elt list; length : int}

module SMap = Map.Make (Script_string)

type view = {
  input_ty : Script.node;
  output_ty : Script.node;
  view_code : Script.node;
}

type ('arg, 'storage) script = {
  code : (('arg, 'storage) pair, (operation boxed_list, 'storage) pair) lambda;
  arg_type : 'arg ty;
  storage : 'storage;
  storage_type : 'storage ty;
  views : view SMap.t;
  root_name : field_annot option;
  code_size : int;
      (* This is an over-approximation of the value size in memory, in
         bytes, of the contract's static part, that is its source
         code. This includes the code of the contract as well as the code
         of the views. The storage size is not taken into account by this
         field as it has a dynamic size. *)
}

(* ---- Instructions --------------------------------------------------------*)
and ('before_top, 'before, 'result_top, 'result) kinstr =
  (*
     Stack
     -----
  *)
  | IDrop :
      ('a, 'b * 's) kinfo * ('b, 's, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | IDup :
      ('a, 's) kinfo * ('a, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISwap :
      ('a, 'b * 's) kinfo * ('b, 'a * 's, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | IConst :
      ('a, 's) kinfo * 'ty * ('ty, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  (*
     Pairs
     -----
  *)
  | ICons_pair :
      ('a, 'b * 's) kinfo * ('a * 'b, 's, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | ICar :
      ('a * 'b, 's) kinfo * ('a, 's, 'r, 'f) kinstr
      -> ('a * 'b, 's, 'r, 'f) kinstr
  | ICdr :
      ('a * 'b, 's) kinfo * ('b, 's, 'r, 'f) kinstr
      -> ('a * 'b, 's, 'r, 'f) kinstr
  | IUnpair :
      ('a * 'b, 's) kinfo * ('a, 'b * 's, 'r, 'f) kinstr
      -> ('a * 'b, 's, 'r, 'f) kinstr
  (*
     Options
     -------
   *)
  | ICons_some :
      ('v, 's) kinfo * ('v option, 's, 'r, 'f) kinstr
      -> ('v, 's, 'r, 'f) kinstr
  | ICons_none :
      ('a, 's) kinfo * 'b ty * ('b option, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IIf_none : {
      kinfo : ('a option, 'b * 's) kinfo;
      branch_if_none : ('b, 's, 'r, 'f) kinstr;
      branch_if_some : ('a, 'b * 's, 'r, 'f) kinstr;
    }
      -> ('a option, 'b * 's, 'r, 'f) kinstr
  (*
     Unions
     ------
   *)
  | ICons_left :
      ('a, 's) kinfo * (('a, 'b) union, 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ICons_right :
      ('b, 's) kinfo * (('a, 'b) union, 's, 'r, 'f) kinstr
      -> ('b, 's, 'r, 'f) kinstr
  | IIf_left : {
      kinfo : (('a, 'b) union, 's) kinfo;
      branch_if_left : ('a, 's, 'r, 'f) kinstr;
      branch_if_right : ('b, 's, 'r, 'f) kinstr;
    }
      -> (('a, 'b) union, 's, 'r, 'f) kinstr
  (*
     Lists
     -----
  *)
  | ICons_list :
      ('a, 'a boxed_list * 's) kinfo * ('a boxed_list, 's, 'r, 'f) kinstr
      -> ('a, 'a boxed_list * 's, 'r, 'f) kinstr
  | INil :
      ('a, 's) kinfo * ('b boxed_list, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IIf_cons : {
      kinfo : ('a boxed_list, 'b * 's) kinfo;
      branch_if_cons : ('a, 'a boxed_list * ('b * 's), 'r, 'f) kinstr;
      branch_if_nil : ('b, 's, 'r, 'f) kinstr;
    }
      -> ('a boxed_list, 'b * 's, 'r, 'f) kinstr
  | IList_map :
      ('a boxed_list, 'c * 's) kinfo
      * ('a, 'c * 's, 'b, 'c * 's) kinstr
      * ('b boxed_list, 'c * 's, 'r, 'f) kinstr
      -> ('a boxed_list, 'c * 's, 'r, 'f) kinstr
  | IList_iter :
      ('a boxed_list, 'b * 's) kinfo
      * ('a, 'b * 's, 'b, 's) kinstr
      * ('b, 's, 'r, 'f) kinstr
      -> ('a boxed_list, 'b * 's, 'r, 'f) kinstr
  | IList_size :
      ('a boxed_list, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> ('a boxed_list, 's, 'r, 'f) kinstr
  (*
    Sets
    ----
  *)
  | IEmpty_set :
      ('a, 's) kinfo * 'b comparable_ty * ('b set, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISet_iter :
      ('a set, 'b * 's) kinfo
      * ('a, 'b * 's, 'b, 's) kinstr
      * ('b, 's, 'r, 'f) kinstr
      -> ('a set, 'b * 's, 'r, 'f) kinstr
  | ISet_mem :
      ('a, 'a set * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> ('a, 'a set * 's, 'r, 'f) kinstr
  | ISet_update :
      ('a, bool * ('a set * 's)) kinfo * ('a set, 's, 'r, 'f) kinstr
      -> ('a, bool * ('a set * 's), 'r, 'f) kinstr
  | ISet_size :
      ('a set, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> ('a set, 's, 'r, 'f) kinstr
  (*
     Maps
     ----
   *)
  | IEmpty_map :
      ('a, 's) kinfo
      * 'b comparable_ty
      * 'c ty
      * (('b, 'c) map, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IMap_map :
      (('a, 'b) map, 'd * 's) kinfo
      * ('a * 'b, 'd * 's, 'c, 'd * 's) kinstr
      * (('a, 'c) map, 'd * 's, 'r, 'f) kinstr
      -> (('a, 'b) map, 'd * 's, 'r, 'f) kinstr
  | IMap_iter :
      (('a, 'b) map, 'c * 's) kinfo
      * ('a * 'b, 'c * 's, 'c, 's) kinstr
      * ('c, 's, 'r, 'f) kinstr
      -> (('a, 'b) map, 'c * 's, 'r, 'f) kinstr
  | IMap_mem :
      ('a, ('a, 'b) map * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> ('a, ('a, 'b) map * 's, 'r, 'f) kinstr
  | IMap_get :
      ('a, ('a, 'b) map * 's) kinfo * ('b option, 's, 'r, 'f) kinstr
      -> ('a, ('a, 'b) map * 's, 'r, 'f) kinstr
  | IMap_update :
      ('a, 'b option * (('a, 'b) map * 's)) kinfo
      * (('a, 'b) map, 's, 'r, 'f) kinstr
      -> ('a, 'b option * (('a, 'b) map * 's), 'r, 'f) kinstr
  | IMap_get_and_update :
      ('a, 'b option * (('a, 'b) map * 's)) kinfo
      * ('b option, ('a, 'b) map * 's, 'r, 'f) kinstr
      -> ('a, 'b option * (('a, 'b) map * 's), 'r, 'f) kinstr
  | IMap_size :
      (('a, 'b) map, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (('a, 'b) map, 's, 'r, 'f) kinstr
  (*
     Big maps
     --------
  *)
  | IEmpty_big_map :
      ('a, 's) kinfo
      * 'b comparable_ty
      * 'c ty
      * (('b, 'c) big_map, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IBig_map_mem :
      ('a, ('a, 'b) big_map * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> ('a, ('a, 'b) big_map * 's, 'r, 'f) kinstr
  | IBig_map_get :
      ('a, ('a, 'b) big_map * 's) kinfo * ('b option, 's, 'r, 'f) kinstr
      -> ('a, ('a, 'b) big_map * 's, 'r, 'f) kinstr
  | IBig_map_update :
      ('a, 'b option * (('a, 'b) big_map * 's)) kinfo
      * (('a, 'b) big_map, 's, 'r, 'f) kinstr
      -> ('a, 'b option * (('a, 'b) big_map * 's), 'r, 'f) kinstr
  | IBig_map_get_and_update :
      ('a, 'b option * (('a, 'b) big_map * 's)) kinfo
      * ('b option, ('a, 'b) big_map * 's, 'r, 'f) kinstr
      -> ('a, 'b option * (('a, 'b) big_map * 's), 'r, 'f) kinstr
  (*
     Strings
     -------
  *)
  | IConcat_string :
      (Script_string.t boxed_list, 's) kinfo
      * (Script_string.t, 's, 'r, 'f) kinstr
      -> (Script_string.t boxed_list, 's, 'r, 'f) kinstr
  | IConcat_string_pair :
      (Script_string.t, Script_string.t * 's) kinfo
      * (Script_string.t, 's, 'r, 'f) kinstr
      -> (Script_string.t, Script_string.t * 's, 'r, 'f) kinstr
  | ISlice_string :
      (n num, n num * (Script_string.t * 's)) kinfo
      * (Script_string.t option, 's, 'r, 'f) kinstr
      -> (n num, n num * (Script_string.t * 's), 'r, 'f) kinstr
  | IString_size :
      (Script_string.t, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (Script_string.t, 's, 'r, 'f) kinstr
  (*
     Bytes
     -----
  *)
  | IConcat_bytes :
      (bytes boxed_list, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes boxed_list, 's, 'r, 'f) kinstr
  | IConcat_bytes_pair :
      (bytes, bytes * 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, bytes * 's, 'r, 'f) kinstr
  | ISlice_bytes :
      (n num, n num * (bytes * 's)) kinfo * (bytes option, 's, 'r, 'f) kinstr
      -> (n num, n num * (bytes * 's), 'r, 'f) kinstr
  | IBytes_size :
      (bytes, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  (*
     Timestamps
     ----------
   *)
  | IAdd_seconds_to_timestamp :
      (z num, Script_timestamp.t * 's) kinfo
      * (Script_timestamp.t, 's, 'r, 'f) kinstr
      -> (z num, Script_timestamp.t * 's, 'r, 'f) kinstr
  | IAdd_timestamp_to_seconds :
      (Script_timestamp.t, z num * 's) kinfo
      * (Script_timestamp.t, 's, 'r, 'f) kinstr
      -> (Script_timestamp.t, z num * 's, 'r, 'f) kinstr
  | ISub_timestamp_seconds :
      (Script_timestamp.t, z num * 's) kinfo
      * (Script_timestamp.t, 's, 'r, 'f) kinstr
      -> (Script_timestamp.t, z num * 's, 'r, 'f) kinstr
  | IDiff_timestamps :
      (Script_timestamp.t, Script_timestamp.t * 's) kinfo
      * (z num, 's, 'r, 'f) kinstr
      -> (Script_timestamp.t, Script_timestamp.t * 's, 'r, 'f) kinstr
  (*
     Tez
     ---
    *)
  | IAdd_tez :
      (Tez.t, Tez.t * 's) kinfo * (Tez.t, 's, 'r, 'f) kinstr
      -> (Tez.t, Tez.t * 's, 'r, 'f) kinstr
  | ISub_tez :
      (Tez.t, Tez.t * 's) kinfo * (Tez.t, 's, 'r, 'f) kinstr
      -> (Tez.t, Tez.t * 's, 'r, 'f) kinstr
  | IMul_teznat :
      (Tez.t, n num * 's) kinfo * (Tez.t, 's, 'r, 'f) kinstr
      -> (Tez.t, n num * 's, 'r, 'f) kinstr
  | IMul_nattez :
      (n num, Tez.t * 's) kinfo * (Tez.t, 's, 'r, 'f) kinstr
      -> (n num, Tez.t * 's, 'r, 'f) kinstr
  | IEdiv_teznat :
      (Tez.t, n num * 's) kinfo
      * ((Tez.t, Tez.t) pair option, 's, 'r, 'f) kinstr
      -> (Tez.t, n num * 's, 'r, 'f) kinstr
  | IEdiv_tez :
      (Tez.t, Tez.t * 's) kinfo
      * ((n num, Tez.t) pair option, 's, 'r, 'f) kinstr
      -> (Tez.t, Tez.t * 's, 'r, 'f) kinstr
  (*
     Booleans
     --------
   *)
  | IOr :
      (bool, bool * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (bool, bool * 's, 'r, 'f) kinstr
  | IAnd :
      (bool, bool * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (bool, bool * 's, 'r, 'f) kinstr
  | IXor :
      (bool, bool * 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (bool, bool * 's, 'r, 'f) kinstr
  | INot :
      (bool, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (bool, 's, 'r, 'f) kinstr
  (*
     Integers
     --------
  *)
  | IIs_nat :
      (z num, 's) kinfo * (n num option, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | INeg_nat :
      (n num, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (n num, 's, 'r, 'f) kinstr
  | INeg_int :
      (z num, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | IAbs_int :
      (z num, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | IInt_nat :
      (n num, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (n num, 's, 'r, 'f) kinstr
  | IAdd_intint :
      (z num, z num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, z num * 's, 'r, 'f) kinstr
  | IAdd_intnat :
      (z num, n num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, n num * 's, 'r, 'f) kinstr
  | IAdd_natint :
      (n num, z num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (n num, z num * 's, 'r, 'f) kinstr
  | IAdd_natnat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | ISub_int :
      ('a num, 'b num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> ('a num, 'b num * 's, 'r, 'f) kinstr
  | IMul_intint :
      (z num, z num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, z num * 's, 'r, 'f) kinstr
  | IMul_intnat :
      (z num, n num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, n num * 's, 'r, 'f) kinstr
  | IMul_natint :
      (n num, z num * 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (n num, z num * 's, 'r, 'f) kinstr
  | IMul_natnat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | IEdiv_intint :
      (z num, z num * 's) kinfo
      * ((z num, n num) pair option, 's, 'r, 'f) kinstr
      -> (z num, z num * 's, 'r, 'f) kinstr
  | IEdiv_intnat :
      (z num, n num * 's) kinfo
      * ((z num, n num) pair option, 's, 'r, 'f) kinstr
      -> (z num, n num * 's, 'r, 'f) kinstr
  | IEdiv_natint :
      (n num, z num * 's) kinfo
      * ((z num, n num) pair option, 's, 'r, 'f) kinstr
      -> (n num, z num * 's, 'r, 'f) kinstr
  | IEdiv_natnat :
      (n num, n num * 's) kinfo
      * ((n num, n num) pair option, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | ILsl_nat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | ILsr_nat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | IOr_nat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | IAnd_nat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | IAnd_int_nat :
      (z num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (z num, n num * 's, 'r, 'f) kinstr
  | IXor_nat :
      (n num, n num * 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (n num, n num * 's, 'r, 'f) kinstr
  | INot_nat :
      (n num, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (n num, 's, 'r, 'f) kinstr
  | INot_int :
      (z num, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  (*
     Control
     -------
  *)
  | IIf : {
      kinfo : (bool, 'a * 's) kinfo;
      branch_if_true : ('a, 's, 'r, 'f) kinstr;
      branch_if_false : ('a, 's, 'r, 'f) kinstr;
    }
      -> (bool, 'a * 's, 'r, 'f) kinstr
  | ILoop :
      (bool, 'a * 's) kinfo
      * ('a, 's, bool, 'a * 's) kinstr
      * ('a, 's, 'r, 'f) kinstr
      -> (bool, 'a * 's, 'r, 'f) kinstr
  | ILoop_left :
      (('a, 'b) union, 's) kinfo
      * ('a, 's, ('a, 'b) union, 's) kinstr
      * ('b, 's, 'r, 'f) kinstr
      -> (('a, 'b) union, 's, 'r, 'f) kinstr
  | IDip :
      ('a, 'b * 's) kinfo
      * ('b, 's, 'c, 't) kinstr
      * ('a, 'c * 't, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | IExec :
      ('a, ('a, 'b) lambda * 's) kinfo * ('b, 's, 'r, 'f) kinstr
      -> ('a, ('a, 'b) lambda * 's, 'r, 'f) kinstr
  | IApply :
      ('a, ('a * 'b, 'c) lambda * 's) kinfo
      * 'a ty
      * (('b, 'c) lambda, 's, 'r, 'f) kinstr
      -> ('a, ('a * 'b, 'c) lambda * 's, 'r, 'f) kinstr
  | ILambda :
      ('a, 's) kinfo
      * ('b, 'c) lambda
      * (('b, 'c) lambda, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IFailwith :
      ('a, 's) kinfo * Script.location * 'a ty * ('b, 't, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  (*
     Comparison
     ----------
  *)
  | ICompare :
      ('a, 'a * 's) kinfo * 'a comparable_ty * (z num, 's, 'r, 'f) kinstr
      -> ('a, 'a * 's, 'r, 'f) kinstr
  (*
     Comparators
     -----------
  *)
  | IEq :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | INeq :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | ILt :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | IGt :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | ILe :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  | IGe :
      (z num, 's) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (z num, 's, 'r, 'f) kinstr
  (*
     Protocol
     --------
  *)
  | IAddress :
      ('a typed_contract, 's) kinfo * (address, 's, 'r, 'f) kinstr
      -> ('a typed_contract, 's, 'r, 'f) kinstr
  | IContract :
      (address, 's) kinfo
      * 'a ty
      * string
      * ('a typed_contract option, 's, 'r, 'f) kinstr
      -> (address, 's, 'r, 'f) kinstr
  | IView :
      ('a, address * 's) kinfo
      * ('a, 'b) view_signature
      * ('b option, 's, 'r, 'f) kinstr
      -> ('a, address * 's, 'r, 'f) kinstr
  | ITransfer_tokens :
      ('a, Tez.t * ('a typed_contract * 's)) kinfo
      * (operation, 's, 'r, 'f) kinstr
      -> ('a, Tez.t * ('a typed_contract * 's), 'r, 'f) kinstr
  | IImplicit_account :
      (public_key_hash, 's) kinfo * (unit typed_contract, 's, 'r, 'f) kinstr
      -> (public_key_hash, 's, 'r, 'f) kinstr
  | ICreate_contract : {
      kinfo : (public_key_hash option, Tez.t * ('a * 's)) kinfo;
      storage_type : 'a ty;
      arg_type : 'b ty;
      lambda : ('b * 'a, operation boxed_list * 'a) lambda;
      views : view SMap.t;
      root_name : field_annot option;
      k : (operation, address * 's, 'r, 'f) kinstr;
    }
      -> (public_key_hash option, Tez.t * ('a * 's), 'r, 'f) kinstr
  | ISet_delegate :
      (public_key_hash option, 's) kinfo * (operation, 's, 'r, 'f) kinstr
      -> (public_key_hash option, 's, 'r, 'f) kinstr
  | INow :
      ('a, 's) kinfo * (Script_timestamp.t, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IBalance :
      ('a, 's) kinfo * (Tez.t, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ILevel :
      ('a, 's) kinfo * (n num, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ICheck_signature :
      (public_key, signature * (bytes * 's)) kinfo * (bool, 's, 'r, 'f) kinstr
      -> (public_key, signature * (bytes * 's), 'r, 'f) kinstr
  | IHash_key :
      (public_key, 's) kinfo * (public_key_hash, 's, 'r, 'f) kinstr
      -> (public_key, 's, 'r, 'f) kinstr
  | IPack :
      ('a, 's) kinfo * 'a ty * (bytes, 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IUnpack :
      (bytes, 's) kinfo * 'a ty * ('a option, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | IBlake2b :
      (bytes, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | ISha256 :
      (bytes, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | ISha512 :
      (bytes, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | ISource :
      ('a, 's) kinfo * (address, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISender :
      ('a, 's) kinfo * (address, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISelf :
      ('a, 's) kinfo
      * 'b ty
      * string
      * ('b typed_contract, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISelf_address :
      ('a, 's) kinfo * (address, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IAmount :
      ('a, 's) kinfo * (Tez.t, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ISapling_empty_state :
      ('a, 's) kinfo
      * Sapling.Memo_size.t
      * (Sapling.state, 'a * 's, 'b, 'f) kinstr
      -> ('a, 's, 'b, 'f) kinstr
  | ISapling_verify_update :
      (Sapling.transaction, Sapling.state * 's) kinfo
      * ((z num, Sapling.state) pair option, 's, 'r, 'f) kinstr
      -> (Sapling.transaction, Sapling.state * 's, 'r, 'f) kinstr
  | IDig :
      ('a, 's) kinfo
      * int
      * ('b, 'c * 't, 'c, 't, 'a, 's, 'd, 'u) stack_prefix_preservation_witness
      * ('b, 'd * 'u, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IDug :
      ('a, 'b * 's) kinfo
      * int
      * ('c, 't, 'a, 'c * 't, 'b, 's, 'd, 'u) stack_prefix_preservation_witness
      * ('d, 'u, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | IDipn :
      ('a, 's) kinfo
      * int
      * ('c, 't, 'd, 'v, 'a, 's, 'b, 'u) stack_prefix_preservation_witness
      * ('c, 't, 'd, 'v) kinstr
      * ('b, 'u, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IDropn :
      ('a, 's) kinfo
      * int
      * ('b, 'u, 'b, 'u, 'a, 's, 'a, 's) stack_prefix_preservation_witness
      * ('b, 'u, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IChainId :
      ('a, 's) kinfo * (Chain_id.t, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | INever : (never, 's) kinfo -> (never, 's, 'r, 'f) kinstr
  | IVoting_power :
      (public_key_hash, 's) kinfo * (n num, 's, 'r, 'f) kinstr
      -> (public_key_hash, 's, 'r, 'f) kinstr
  | ITotal_voting_power :
      ('a, 's) kinfo * (n num, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IKeccak :
      (bytes, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | ISha3 :
      (bytes, 's) kinfo * (bytes, 's, 'r, 'f) kinstr
      -> (bytes, 's, 'r, 'f) kinstr
  | IAdd_bls12_381_g1 :
      (Bls12_381.G1.t, Bls12_381.G1.t * 's) kinfo
      * (Bls12_381.G1.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G1.t, Bls12_381.G1.t * 's, 'r, 'f) kinstr
  | IAdd_bls12_381_g2 :
      (Bls12_381.G2.t, Bls12_381.G2.t * 's) kinfo
      * (Bls12_381.G2.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G2.t, Bls12_381.G2.t * 's, 'r, 'f) kinstr
  | IAdd_bls12_381_fr :
      (Bls12_381.Fr.t, Bls12_381.Fr.t * 's) kinfo
      * (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.Fr.t, Bls12_381.Fr.t * 's, 'r, 'f) kinstr
  | IMul_bls12_381_g1 :
      (Bls12_381.G1.t, Bls12_381.Fr.t * 's) kinfo
      * (Bls12_381.G1.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G1.t, Bls12_381.Fr.t * 's, 'r, 'f) kinstr
  | IMul_bls12_381_g2 :
      (Bls12_381.G2.t, Bls12_381.Fr.t * 's) kinfo
      * (Bls12_381.G2.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G2.t, Bls12_381.Fr.t * 's, 'r, 'f) kinstr
  | IMul_bls12_381_fr :
      (Bls12_381.Fr.t, Bls12_381.Fr.t * 's) kinfo
      * (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.Fr.t, Bls12_381.Fr.t * 's, 'r, 'f) kinstr
  | IMul_bls12_381_z_fr :
      (Bls12_381.Fr.t, 'a num * 's) kinfo * (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.Fr.t, 'a num * 's, 'r, 'f) kinstr
  | IMul_bls12_381_fr_z :
      ('a num, Bls12_381.Fr.t * 's) kinfo * (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
      -> ('a num, Bls12_381.Fr.t * 's, 'r, 'f) kinstr
  | IInt_bls12_381_fr :
      (Bls12_381.Fr.t, 's) kinfo * (z num, 's, 'r, 'f) kinstr
      -> (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
  | INeg_bls12_381_g1 :
      (Bls12_381.G1.t, 's) kinfo * (Bls12_381.G1.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G1.t, 's, 'r, 'f) kinstr
  | INeg_bls12_381_g2 :
      (Bls12_381.G2.t, 's) kinfo * (Bls12_381.G2.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.G2.t, 's, 'r, 'f) kinstr
  | INeg_bls12_381_fr :
      (Bls12_381.Fr.t, 's) kinfo * (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
      -> (Bls12_381.Fr.t, 's, 'r, 'f) kinstr
  | IPairing_check_bls12_381 :
      ((Bls12_381.G1.t, Bls12_381.G2.t) pair boxed_list, 's) kinfo
      * (bool, 's, 'r, 'f) kinstr
      -> ((Bls12_381.G1.t, Bls12_381.G2.t) pair boxed_list, 's, 'r, 'f) kinstr
  | IComb :
      ('a, 's) kinfo
      * int
      * ('a * 's, 'b * 'u) comb_gadt_witness
      * ('b, 'u, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IUncomb :
      ('a, 's) kinfo
      * int
      * ('a * 's, 'b * 'u) uncomb_gadt_witness
      * ('b, 'u, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | IComb_get :
      ('t, 's) kinfo
      * int
      * ('t, 'v) comb_get_gadt_witness
      * ('v, 's, 'r, 'f) kinstr
      -> ('t, 's, 'r, 'f) kinstr
  | IComb_set :
      ('a, 'b * 's) kinfo
      * int
      * ('a, 'b, 'c) comb_set_gadt_witness
      * ('c, 's, 'r, 'f) kinstr
      -> ('a, 'b * 's, 'r, 'f) kinstr
  | IDup_n :
      ('a, 's) kinfo
      * int
      * ('a * 's, 't) dup_n_gadt_witness
      * ('t, 'a * 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr
  | ITicket :
      ('a, n num * 's) kinfo * ('a ticket, 's, 'r, 'f) kinstr
      -> ('a, n num * 's, 'r, 'f) kinstr
  | IRead_ticket :
      ('a ticket, 's) kinfo
      * (address * ('a * n num), 'a ticket * 's, 'r, 'f) kinstr
      -> ('a ticket, 's, 'r, 'f) kinstr
  | ISplit_ticket :
      ('a ticket, (n num * n num) * 's) kinfo
      * (('a ticket * 'a ticket) option, 's, 'r, 'f) kinstr
      -> ('a ticket, (n num * n num) * 's, 'r, 'f) kinstr
  | IJoin_tickets :
      ('a ticket * 'a ticket, 's) kinfo
      * 'a comparable_ty
      * ('a ticket option, 's, 'r, 'f) kinstr
      -> ('a ticket * 'a ticket, 's, 'r, 'f) kinstr
  | IOpen_chest :
      (Timelock.chest_key, Timelock.chest * (n num * 's)) kinfo
      * ((bytes, bool) union, 's, 'r, 'f) kinstr
      -> (Timelock.chest_key, Timelock.chest * (n num * 's), 'r, 'f) kinstr
  (*
     Internal control instructions
     -----------------------------
  *)
  | IHalt : ('a, 's) kinfo -> ('a, 's, 'a, 's) kinstr
  | ILog :
      ('a, 's) kinfo * logging_event * logger * ('a, 's, 'r, 'f) kinstr
      -> ('a, 's, 'r, 'f) kinstr

and logging_event =
  | LogEntry : logging_event
  | LogExit : ('b, 'u) kinfo -> logging_event

and ('arg, 'ret) lambda =
  | Lam :
      ('arg, end_of_stack, 'ret, end_of_stack) kdescr * Script.node
      -> ('arg, 'ret) lambda
[@@coq_force_gadt]

and 'arg typed_contract = 'arg ty * address

and (_, _, _, _) continuation =
  | KNil : ('r, 'f, 'r, 'f) continuation
  | KCons :
      ('a, 's, 'b, 't) kinstr * ('b, 't, 'r, 'f) continuation
      -> ('a, 's, 'r, 'f) continuation
  | KReturn :
      's * ('a, 's, 'r, 'f) continuation
      -> ('a, end_of_stack, 'r, 'f) continuation
  | KUndip :
      'b * ('b, 'a * 's, 'r, 'f) continuation
      -> ('a, 's, 'r, 'f) continuation
  | KLoop_in :
      ('a, 's, bool, 'a * 's) kinstr * ('a, 's, 'r, 'f) continuation
      -> (bool, 'a * 's, 'r, 'f) continuation
  | KLoop_in_left :
      ('a, 's, ('a, 'b) union, 's) kinstr * ('b, 's, 'r, 'f) continuation
      -> (('a, 'b) union, 's, 'r, 'f) continuation
  | KIter :
      ('a, 'b * 's, 'b, 's) kinstr * 'a list * ('b, 's, 'r, 'f) continuation
      -> ('b, 's, 'r, 'f) continuation
  | KList_enter_body :
      ('a, 'c * 's, 'b, 'c * 's) kinstr
      * 'a list
      * 'b list
      * int
      * ('b boxed_list, 'c * 's, 'r, 'f) continuation
      -> ('c, 's, 'r, 'f) continuation
  | KList_exit_body :
      ('a, 'c * 's, 'b, 'c * 's) kinstr
      * 'a list
      * 'b list
      * int
      * ('b boxed_list, 'c * 's, 'r, 'f) continuation
      -> ('b, 'c * 's, 'r, 'f) continuation
  | KMap_enter_body :
      ('a * 'b, 'd * 's, 'c, 'd * 's) kinstr
      * ('a * 'b) list
      * ('a, 'c) map
      * (('a, 'c) map, 'd * 's, 'r, 'f) continuation
      -> ('d, 's, 'r, 'f) continuation
  | KMap_exit_body :
      ('a * 'b, 'd * 's, 'c, 'd * 's) kinstr
      * ('a * 'b) list
      * ('a, 'c) map
      * 'a
      * (('a, 'c) map, 'd * 's, 'r, 'f) continuation
      -> ('c, 'd * 's, 'r, 'f) continuation
  | KLog :
      ('a, 's, 'r, 'f) continuation * logger
      -> ('a, 's, 'r, 'f) continuation

and ('a, 's, 'b, 'f, 'c, 'u) logging_function =
  ('a, 's, 'b, 'f) kinstr ->
  context ->
  Script.location ->
  ('c, 'u) stack_ty ->
  'c * 'u ->
  unit

and execution_trace =
  (Script.location * Gas.t * (Script.expr * string option) list) list

and logger = {
  log_interp : 'a 's 'b 'f 'c 'u. ('a, 's, 'b, 'f, 'c, 'u) logging_function;
  log_entry : 'a 's 'b 'f. ('a, 's, 'b, 'f, 'a, 's) logging_function;
  log_control : 'a 's 'b 'f. ('a, 's, 'b, 'f) continuation -> unit;
  log_exit : 'a 's 'b 'f 'c 'u. ('a, 's, 'b, 'f, 'c, 'u) logging_function;
  get_log : unit -> execution_trace option tzresult Lwt.t;
}

(* ---- Auxiliary types -----------------------------------------------------*)
and 'ty ty =
  | Unit_t : unit ty_metadata -> unit ty
  | Int_t : z num ty_metadata -> z num ty
  | Nat_t : n num ty_metadata -> n num ty
  | Signature_t : signature ty_metadata -> signature ty
  | String_t : Script_string.t ty_metadata -> Script_string.t ty
  | Bytes_t : Bytes.t ty_metadata -> bytes ty
  | Mutez_t : Tez.t ty_metadata -> Tez.t ty
  | Key_hash_t : public_key_hash ty_metadata -> public_key_hash ty
  | Key_t : public_key ty_metadata -> public_key ty
  | Timestamp_t : Script_timestamp.t ty_metadata -> Script_timestamp.t ty
  | Address_t : address ty_metadata -> address ty
  | Bool_t : bool ty_metadata -> bool ty
  | Pair_t :
      ('a ty * field_annot option * var_annot option)
      * ('b ty * field_annot option * var_annot option)
      * ('a, 'b) pair ty_metadata
      -> ('a, 'b) pair ty
  | Union_t :
      ('a ty * field_annot option)
      * ('b ty * field_annot option)
      * ('a, 'b) union ty_metadata
      -> ('a, 'b) union ty
  | Lambda_t :
      'arg ty * 'ret ty * ('arg, 'ret) lambda ty_metadata
      -> ('arg, 'ret) lambda ty
  | Option_t : 'v ty * 'v option ty_metadata -> 'v option ty
  | List_t : 'v ty * 'v boxed_list ty_metadata -> 'v boxed_list ty
  | Set_t : 'v comparable_ty * 'v set ty_metadata -> 'v set ty
  | Map_t :
      'k comparable_ty * 'v ty * ('k, 'v) map ty_metadata
      -> ('k, 'v) map ty
  | Big_map_t :
      'k comparable_ty * 'v ty * ('k, 'v) big_map ty_metadata
      -> ('k, 'v) big_map ty
  | Contract_t :
      'arg ty * 'arg typed_contract ty_metadata
      -> 'arg typed_contract ty
  | Sapling_transaction_t :
      Sapling.Memo_size.t * Sapling.transaction ty_metadata
      -> Sapling.transaction ty
  | Sapling_state_t :
      Sapling.Memo_size.t * Sapling.state ty_metadata
      -> Sapling.state ty
  | Operation_t : operation ty_metadata -> operation ty
  | Chain_id_t : Chain_id.t ty_metadata -> Chain_id.t ty
  | Never_t : never ty_metadata -> never ty
  | Bls12_381_g1_t : Bls12_381.G1.t ty_metadata -> Bls12_381.G1.t ty
  | Bls12_381_g2_t : Bls12_381.G2.t ty_metadata -> Bls12_381.G2.t ty
  | Bls12_381_fr_t : Bls12_381.Fr.t ty_metadata -> Bls12_381.Fr.t ty
  | Ticket_t : 'a comparable_ty * 'a ticket ty_metadata -> 'a ticket ty
  | Chest_key_t : Timelock.chest_key ty_metadata -> Timelock.chest_key ty
  | Chest_t : Timelock.chest ty_metadata -> Timelock.chest ty

and ('top_ty, 'resty) stack_ty =
  | Item_t :
      'ty ty * ('ty2, 'rest) stack_ty * var_annot option
      -> ('ty, 'ty2 * 'rest) stack_ty
  | Bot_t : (empty_cell, empty_cell) stack_ty

and ('key, 'value) big_map = {
  id : Big_map.Id.t option;
  diff : ('key, 'value) big_map_overlay;
  key_type : 'key comparable_ty;
  value_type : 'value ty;
}

and ('a, 's, 'r, 'f) kdescr = {
  kloc : Script.location;
  kbef : ('a, 's) stack_ty;
  kaft : ('r, 'f) stack_ty;
  kinstr : ('a, 's, 'r, 'f) kinstr;
}

and ('a, 's) kinfo = {iloc : Script.location; kstack_ty : ('a, 's) stack_ty}

and (_, _, _, _, _, _, _, _) stack_prefix_preservation_witness =
  | KPrefix :
      ('y, 'u) kinfo
      * ('c, 'v, 'd, 'w, 'x, 's, 'y, 'u) stack_prefix_preservation_witness
      -> ( 'c,
           'v,
           'd,
           'w,
           'a,
           'x * 's,
           'a,
           'y * 'u )
         stack_prefix_preservation_witness
  | KRest : ('a, 's, 'b, 'u, 'a, 's, 'b, 'u) stack_prefix_preservation_witness

and ('before, 'after) comb_gadt_witness =
  | Comb_one : ('a * ('x * 'before), 'a * ('x * 'before)) comb_gadt_witness
  | Comb_succ :
      ('before, 'b * 'after) comb_gadt_witness
      -> ('a * 'before, ('a * 'b) * 'after) comb_gadt_witness

and ('before, 'after) uncomb_gadt_witness =
  | Uncomb_one : ('rest, 'rest) uncomb_gadt_witness
  | Uncomb_succ :
      ('b * 'before, 'after) uncomb_gadt_witness
      -> (('a * 'b) * 'before, 'a * 'after) uncomb_gadt_witness

and ('before, 'after) comb_get_gadt_witness =
  | Comb_get_zero : ('b, 'b) comb_get_gadt_witness
  | Comb_get_one : ('a * 'b, 'a) comb_get_gadt_witness
  | Comb_get_plus_two :
      ('before, 'after) comb_get_gadt_witness
      -> ('a * 'before, 'after) comb_get_gadt_witness

and ('value, 'before, 'after) comb_set_gadt_witness =
  | Comb_set_zero : ('value, _, 'value) comb_set_gadt_witness
  | Comb_set_one : ('value, 'hd * 'tl, 'value * 'tl) comb_set_gadt_witness
  | Comb_set_plus_two :
      ('value, 'before, 'after) comb_set_gadt_witness
      -> ('value, 'a * 'before, 'a * 'after) comb_set_gadt_witness
[@@coq_force_gadt]

and (_, _) dup_n_gadt_witness =
  | Dup_n_zero : ('a * 'rest, 'a) dup_n_gadt_witness
  | Dup_n_succ :
      ('stack, 'b) dup_n_gadt_witness
      -> ('a * 'stack, 'b) dup_n_gadt_witness

and ('a, 'b) view_signature =
  | View_signature of {
      name : Script_string.t;
      input_ty : 'a ty;
      output_ty : 'b ty;
    }

let kinfo_of_kinstr : type a s b f. (a, s, b, f) kinstr -> (a, s) kinfo =
 fun i ->
  match i with
  | IDrop (kinfo, _) -> kinfo
  | IDup (kinfo, _) -> kinfo
  | ISwap (kinfo, _) -> kinfo
  | IConst (kinfo, _, _) -> kinfo
  | ICons_pair (kinfo, _) -> kinfo
  | ICar (kinfo, _) -> kinfo
  | ICdr (kinfo, _) -> kinfo
  | IUnpair (kinfo, _) -> kinfo
  | ICons_some (kinfo, _) -> kinfo
  | ICons_none (kinfo, _, _) -> kinfo
  | IIf_none {kinfo; _} -> kinfo
  | ICons_left (kinfo, _) -> kinfo
  | ICons_right (kinfo, _) -> kinfo
  | IIf_left {kinfo; _} -> kinfo
  | ICons_list (kinfo, _) -> kinfo
  | INil (kinfo, _) -> kinfo
  | IIf_cons {kinfo; _} -> kinfo
  | IList_map (kinfo, _, _) -> kinfo
  | IList_iter (kinfo, _, _) -> kinfo
  | IList_size (kinfo, _) -> kinfo
  | IEmpty_set (kinfo, _, _) -> kinfo
  | ISet_iter (kinfo, _, _) -> kinfo
  | ISet_mem (kinfo, _) -> kinfo
  | ISet_update (kinfo, _) -> kinfo
  | ISet_size (kinfo, _) -> kinfo
  | IEmpty_map (kinfo, _, _, _) -> kinfo
  | IMap_map (kinfo, _, _) -> kinfo
  | IMap_iter (kinfo, _, _) -> kinfo
  | IMap_mem (kinfo, _) -> kinfo
  | IMap_get (kinfo, _) -> kinfo
  | IMap_update (kinfo, _) -> kinfo
  | IMap_get_and_update (kinfo, _) -> kinfo
  | IMap_size (kinfo, _) -> kinfo
  | IEmpty_big_map (kinfo, _, _, _) -> kinfo
  | IBig_map_mem (kinfo, _) -> kinfo
  | IBig_map_get (kinfo, _) -> kinfo
  | IBig_map_update (kinfo, _) -> kinfo
  | IBig_map_get_and_update (kinfo, _) -> kinfo
  | IConcat_string (kinfo, _) -> kinfo
  | IConcat_string_pair (kinfo, _) -> kinfo
  | ISlice_string (kinfo, _) -> kinfo
  | IString_size (kinfo, _) -> kinfo
  | IConcat_bytes (kinfo, _) -> kinfo
  | IConcat_bytes_pair (kinfo, _) -> kinfo
  | ISlice_bytes (kinfo, _) -> kinfo
  | IBytes_size (kinfo, _) -> kinfo
  | IAdd_seconds_to_timestamp (kinfo, _) -> kinfo
  | IAdd_timestamp_to_seconds (kinfo, _) -> kinfo
  | ISub_timestamp_seconds (kinfo, _) -> kinfo
  | IDiff_timestamps (kinfo, _) -> kinfo
  | IAdd_tez (kinfo, _) -> kinfo
  | ISub_tez (kinfo, _) -> kinfo
  | IMul_teznat (kinfo, _) -> kinfo
  | IMul_nattez (kinfo, _) -> kinfo
  | IEdiv_teznat (kinfo, _) -> kinfo
  | IEdiv_tez (kinfo, _) -> kinfo
  | IOr (kinfo, _) -> kinfo
  | IAnd (kinfo, _) -> kinfo
  | IXor (kinfo, _) -> kinfo
  | INot (kinfo, _) -> kinfo
  | IIs_nat (kinfo, _) -> kinfo
  | INeg_nat (kinfo, _) -> kinfo
  | INeg_int (kinfo, _) -> kinfo
  | IAbs_int (kinfo, _) -> kinfo
  | IInt_nat (kinfo, _) -> kinfo
  | IAdd_intint (kinfo, _) -> kinfo
  | IAdd_intnat (kinfo, _) -> kinfo
  | IAdd_natint (kinfo, _) -> kinfo
  | IAdd_natnat (kinfo, _) -> kinfo
  | ISub_int (kinfo, _) -> kinfo
  | IMul_intint (kinfo, _) -> kinfo
  | IMul_intnat (kinfo, _) -> kinfo
  | IMul_natint (kinfo, _) -> kinfo
  | IMul_natnat (kinfo, _) -> kinfo
  | IEdiv_intint (kinfo, _) -> kinfo
  | IEdiv_intnat (kinfo, _) -> kinfo
  | IEdiv_natint (kinfo, _) -> kinfo
  | IEdiv_natnat (kinfo, _) -> kinfo
  | ILsl_nat (kinfo, _) -> kinfo
  | ILsr_nat (kinfo, _) -> kinfo
  | IOr_nat (kinfo, _) -> kinfo
  | IAnd_nat (kinfo, _) -> kinfo
  | IAnd_int_nat (kinfo, _) -> kinfo
  | IXor_nat (kinfo, _) -> kinfo
  | INot_nat (kinfo, _) -> kinfo
  | INot_int (kinfo, _) -> kinfo
  | IIf {kinfo; _} -> kinfo
  | ILoop (kinfo, _, _) -> kinfo
  | ILoop_left (kinfo, _, _) -> kinfo
  | IDip (kinfo, _, _) -> kinfo
  | IExec (kinfo, _) -> kinfo
  | IApply (kinfo, _, _) -> kinfo
  | ILambda (kinfo, _, _) -> kinfo
  | IFailwith (kinfo, _, _, _) -> kinfo
  | ICompare (kinfo, _, _) -> kinfo
  | IEq (kinfo, _) -> kinfo
  | INeq (kinfo, _) -> kinfo
  | ILt (kinfo, _) -> kinfo
  | IGt (kinfo, _) -> kinfo
  | ILe (kinfo, _) -> kinfo
  | IGe (kinfo, _) -> kinfo
  | IAddress (kinfo, _) -> kinfo
  | IContract (kinfo, _, _, _) -> kinfo
  | ITransfer_tokens (kinfo, _) -> kinfo
  | IView (kinfo, _, _) -> kinfo
  | IImplicit_account (kinfo, _) -> kinfo
  | ICreate_contract {kinfo; _} -> kinfo
  | ISet_delegate (kinfo, _) -> kinfo
  | INow (kinfo, _) -> kinfo
  | IBalance (kinfo, _) -> kinfo
  | ILevel (kinfo, _) -> kinfo
  | ICheck_signature (kinfo, _) -> kinfo
  | IHash_key (kinfo, _) -> kinfo
  | IPack (kinfo, _, _) -> kinfo
  | IUnpack (kinfo, _, _) -> kinfo
  | IBlake2b (kinfo, _) -> kinfo
  | ISha256 (kinfo, _) -> kinfo
  | ISha512 (kinfo, _) -> kinfo
  | ISource (kinfo, _) -> kinfo
  | ISender (kinfo, _) -> kinfo
  | ISelf (kinfo, _, _, _) -> kinfo
  | ISelf_address (kinfo, _) -> kinfo
  | IAmount (kinfo, _) -> kinfo
  | ISapling_empty_state (kinfo, _, _) -> kinfo
  | ISapling_verify_update (kinfo, _) -> kinfo
  | IDig (kinfo, _, _, _) -> kinfo
  | IDug (kinfo, _, _, _) -> kinfo
  | IDipn (kinfo, _, _, _, _) -> kinfo
  | IDropn (kinfo, _, _, _) -> kinfo
  | IChainId (kinfo, _) -> kinfo
  | INever kinfo -> kinfo
  | IVoting_power (kinfo, _) -> kinfo
  | ITotal_voting_power (kinfo, _) -> kinfo
  | IKeccak (kinfo, _) -> kinfo
  | ISha3 (kinfo, _) -> kinfo
  | IAdd_bls12_381_g1 (kinfo, _) -> kinfo
  | IAdd_bls12_381_g2 (kinfo, _) -> kinfo
  | IAdd_bls12_381_fr (kinfo, _) -> kinfo
  | IMul_bls12_381_g1 (kinfo, _) -> kinfo
  | IMul_bls12_381_g2 (kinfo, _) -> kinfo
  | IMul_bls12_381_fr (kinfo, _) -> kinfo
  | IMul_bls12_381_z_fr (kinfo, _) -> kinfo
  | IMul_bls12_381_fr_z (kinfo, _) -> kinfo
  | IInt_bls12_381_fr (kinfo, _) -> kinfo
  | INeg_bls12_381_g1 (kinfo, _) -> kinfo
  | INeg_bls12_381_g2 (kinfo, _) -> kinfo
  | INeg_bls12_381_fr (kinfo, _) -> kinfo
  | IPairing_check_bls12_381 (kinfo, _) -> kinfo
  | IComb (kinfo, _, _, _) -> kinfo
  | IUncomb (kinfo, _, _, _) -> kinfo
  | IComb_get (kinfo, _, _, _) -> kinfo
  | IComb_set (kinfo, _, _, _) -> kinfo
  | IDup_n (kinfo, _, _, _) -> kinfo
  | ITicket (kinfo, _) -> kinfo
  | IRead_ticket (kinfo, _) -> kinfo
  | ISplit_ticket (kinfo, _) -> kinfo
  | IJoin_tickets (kinfo, _, _) -> kinfo
  | IHalt kinfo -> kinfo
  | ILog (kinfo, _, _, _) -> kinfo
  | IOpen_chest (kinfo, _) -> kinfo

type kinstr_rewritek = {
  apply : 'b 'u 'r 'f. ('b, 'u, 'r, 'f) kinstr -> ('b, 'u, 'r, 'f) kinstr;
}

let kinstr_rewritek :
    type a s r f. (a, s, r, f) kinstr -> kinstr_rewritek -> (a, s, r, f) kinstr
    =
 fun i f ->
  match i with
  | IDrop (kinfo, k) -> IDrop (kinfo, f.apply k)
  | IDup (kinfo, k) -> IDup (kinfo, f.apply k)
  | ISwap (kinfo, k) -> ISwap (kinfo, f.apply k)
  | IConst (kinfo, x, k) -> IConst (kinfo, x, f.apply k)
  | ICons_pair (kinfo, k) -> ICons_pair (kinfo, f.apply k)
  | ICar (kinfo, k) -> ICar (kinfo, f.apply k)
  | ICdr (kinfo, k) -> ICdr (kinfo, f.apply k)
  | IUnpair (kinfo, k) -> IUnpair (kinfo, f.apply k)
  | ICons_some (kinfo, k) -> ICons_some (kinfo, f.apply k)
  | ICons_none (kinfo, ty, k) -> ICons_none (kinfo, ty, f.apply k)
  | IIf_none {kinfo; branch_if_none; branch_if_some} ->
      let branch_if_none = f.apply branch_if_none
      and branch_if_some = f.apply branch_if_some in
      IIf_none {kinfo; branch_if_none; branch_if_some}
  | ICons_left (kinfo, k) -> ICons_left (kinfo, f.apply k)
  | ICons_right (kinfo, k) -> ICons_right (kinfo, f.apply k)
  | IIf_left {kinfo; branch_if_left; branch_if_right} ->
      let branch_if_left = f.apply branch_if_left
      and branch_if_right = f.apply branch_if_right in
      IIf_left {kinfo; branch_if_left; branch_if_right}
  | ICons_list (kinfo, k) -> ICons_list (kinfo, f.apply k)
  | INil (kinfo, k) -> INil (kinfo, f.apply k)
  | IIf_cons {kinfo; branch_if_cons; branch_if_nil} ->
      let branch_if_nil = f.apply branch_if_nil
      and branch_if_cons = f.apply branch_if_cons in
      IIf_cons {kinfo; branch_if_cons; branch_if_nil}
  | IList_map (kinfo, body, k) -> IList_map (kinfo, f.apply body, f.apply k)
  | IList_iter (kinfo, body, k) -> IList_iter (kinfo, f.apply body, f.apply k)
  | IList_size (kinfo, k) -> IList_size (kinfo, f.apply k)
  | IEmpty_set (kinfo, ty, k) -> IEmpty_set (kinfo, ty, f.apply k)
  | ISet_iter (kinfo, body, k) -> ISet_iter (kinfo, f.apply body, f.apply k)
  | ISet_mem (kinfo, k) -> ISet_mem (kinfo, f.apply k)
  | ISet_update (kinfo, k) -> ISet_update (kinfo, f.apply k)
  | ISet_size (kinfo, k) -> ISet_size (kinfo, f.apply k)
  | IEmpty_map (kinfo, cty, ty, k) -> IEmpty_map (kinfo, cty, ty, f.apply k)
  | IMap_map (kinfo, body, k) -> IMap_map (kinfo, f.apply body, f.apply k)
  | IMap_iter (kinfo, body, k) -> IMap_iter (kinfo, f.apply body, f.apply k)
  | IMap_mem (kinfo, k) -> IMap_mem (kinfo, f.apply k)
  | IMap_get (kinfo, k) -> IMap_get (kinfo, f.apply k)
  | IMap_update (kinfo, k) -> IMap_update (kinfo, f.apply k)
  | IMap_get_and_update (kinfo, k) -> IMap_get_and_update (kinfo, f.apply k)
  | IMap_size (kinfo, k) -> IMap_size (kinfo, f.apply k)
  | IEmpty_big_map (kinfo, cty, ty, k) ->
      IEmpty_big_map (kinfo, cty, ty, f.apply k)
  | IBig_map_mem (kinfo, k) -> IBig_map_mem (kinfo, f.apply k)
  | IBig_map_get (kinfo, k) -> IBig_map_get (kinfo, f.apply k)
  | IBig_map_update (kinfo, k) -> IBig_map_update (kinfo, f.apply k)
  | IBig_map_get_and_update (kinfo, k) ->
      IBig_map_get_and_update (kinfo, f.apply k)
  | IConcat_string (kinfo, k) -> IConcat_string (kinfo, f.apply k)
  | IConcat_string_pair (kinfo, k) -> IConcat_string_pair (kinfo, f.apply k)
  | ISlice_string (kinfo, k) -> ISlice_string (kinfo, f.apply k)
  | IString_size (kinfo, k) -> IString_size (kinfo, f.apply k)
  | IConcat_bytes (kinfo, k) -> IConcat_bytes (kinfo, f.apply k)
  | IConcat_bytes_pair (kinfo, k) -> IConcat_bytes_pair (kinfo, f.apply k)
  | ISlice_bytes (kinfo, k) -> ISlice_bytes (kinfo, f.apply k)
  | IBytes_size (kinfo, k) -> IBytes_size (kinfo, f.apply k)
  | IAdd_seconds_to_timestamp (kinfo, k) ->
      IAdd_seconds_to_timestamp (kinfo, f.apply k)
  | IAdd_timestamp_to_seconds (kinfo, k) ->
      IAdd_timestamp_to_seconds (kinfo, f.apply k)
  | ISub_timestamp_seconds (kinfo, k) ->
      ISub_timestamp_seconds (kinfo, f.apply k)
  | IDiff_timestamps (kinfo, k) -> IDiff_timestamps (kinfo, f.apply k)
  | IAdd_tez (kinfo, k) -> IAdd_tez (kinfo, f.apply k)
  | ISub_tez (kinfo, k) -> ISub_tez (kinfo, f.apply k)
  | IMul_teznat (kinfo, k) -> IMul_teznat (kinfo, f.apply k)
  | IMul_nattez (kinfo, k) -> IMul_nattez (kinfo, f.apply k)
  | IEdiv_teznat (kinfo, k) -> IEdiv_teznat (kinfo, f.apply k)
  | IEdiv_tez (kinfo, k) -> IEdiv_tez (kinfo, f.apply k)
  | IOr (kinfo, k) -> IOr (kinfo, f.apply k)
  | IAnd (kinfo, k) -> IAnd (kinfo, f.apply k)
  | IXor (kinfo, k) -> IXor (kinfo, f.apply k)
  | INot (kinfo, k) -> INot (kinfo, f.apply k)
  | IIs_nat (kinfo, k) -> IIs_nat (kinfo, f.apply k)
  | INeg_nat (kinfo, k) -> INeg_nat (kinfo, f.apply k)
  | INeg_int (kinfo, k) -> INeg_int (kinfo, f.apply k)
  | IAbs_int (kinfo, k) -> IAbs_int (kinfo, f.apply k)
  | IInt_nat (kinfo, k) -> IInt_nat (kinfo, f.apply k)
  | IAdd_intint (kinfo, k) -> IAdd_intint (kinfo, f.apply k)
  | IAdd_intnat (kinfo, k) -> IAdd_intnat (kinfo, f.apply k)
  | IAdd_natint (kinfo, k) -> IAdd_natint (kinfo, f.apply k)
  | IAdd_natnat (kinfo, k) -> IAdd_natnat (kinfo, f.apply k)
  | ISub_int (kinfo, k) -> ISub_int (kinfo, f.apply k)
  | IMul_intint (kinfo, k) -> IMul_intint (kinfo, f.apply k)
  | IMul_intnat (kinfo, k) -> IMul_intnat (kinfo, f.apply k)
  | IMul_natint (kinfo, k) -> IMul_natint (kinfo, f.apply k)
  | IMul_natnat (kinfo, k) -> IMul_natnat (kinfo, f.apply k)
  | IEdiv_intint (kinfo, k) -> IEdiv_intint (kinfo, f.apply k)
  | IEdiv_intnat (kinfo, k) -> IEdiv_intnat (kinfo, f.apply k)
  | IEdiv_natint (kinfo, k) -> IEdiv_natint (kinfo, f.apply k)
  | IEdiv_natnat (kinfo, k) -> IEdiv_natnat (kinfo, f.apply k)
  | ILsl_nat (kinfo, k) -> ILsl_nat (kinfo, f.apply k)
  | ILsr_nat (kinfo, k) -> ILsr_nat (kinfo, f.apply k)
  | IOr_nat (kinfo, k) -> IOr_nat (kinfo, f.apply k)
  | IAnd_nat (kinfo, k) -> IAnd_nat (kinfo, f.apply k)
  | IAnd_int_nat (kinfo, k) -> IAnd_int_nat (kinfo, f.apply k)
  | IXor_nat (kinfo, k) -> IXor_nat (kinfo, f.apply k)
  | INot_nat (kinfo, k) -> INot_nat (kinfo, f.apply k)
  | INot_int (kinfo, k) -> INot_int (kinfo, f.apply k)
  | IIf {kinfo; branch_if_true; branch_if_false} ->
      let branch_if_true = f.apply branch_if_true
      and branch_if_false = f.apply branch_if_false in
      IIf {kinfo; branch_if_true; branch_if_false}
  | ILoop (kinfo, kbody, k) -> ILoop (kinfo, f.apply kbody, f.apply k)
  | ILoop_left (kinfo, kl, kr) -> ILoop_left (kinfo, f.apply kl, f.apply kr)
  | IDip (kinfo, body, k) -> IDip (kinfo, f.apply body, f.apply k)
  | IExec (kinfo, k) -> IExec (kinfo, f.apply k)
  | IApply (kinfo, ty, k) -> IApply (kinfo, ty, f.apply k)
  | ILambda (kinfo, l, k) -> ILambda (kinfo, l, f.apply k)
  | IFailwith (kinfo, i, ty, k) -> IFailwith (kinfo, i, ty, f.apply k)
  | ICompare (kinfo, ty, k) -> ICompare (kinfo, ty, f.apply k)
  | IEq (kinfo, k) -> IEq (kinfo, f.apply k)
  | INeq (kinfo, k) -> INeq (kinfo, f.apply k)
  | ILt (kinfo, k) -> ILt (kinfo, f.apply k)
  | IGt (kinfo, k) -> IGt (kinfo, f.apply k)
  | ILe (kinfo, k) -> ILe (kinfo, f.apply k)
  | IGe (kinfo, k) -> IGe (kinfo, f.apply k)
  | IAddress (kinfo, k) -> IAddress (kinfo, f.apply k)
  | IContract (kinfo, ty, code, k) -> IContract (kinfo, ty, code, f.apply k)
  | ITransfer_tokens (kinfo, k) -> ITransfer_tokens (kinfo, f.apply k)
  | IView (kinfo, view_signature, k) -> IView (kinfo, view_signature, f.apply k)
  | IImplicit_account (kinfo, k) -> IImplicit_account (kinfo, f.apply k)
  | ICreate_contract
      {kinfo; storage_type; arg_type; lambda; views; root_name; k} ->
      let k = f.apply k in
      ICreate_contract
        {kinfo; storage_type; arg_type; lambda; views; root_name; k}
  | ISet_delegate (kinfo, k) -> ISet_delegate (kinfo, f.apply k)
  | INow (kinfo, k) -> INow (kinfo, f.apply k)
  | IBalance (kinfo, k) -> IBalance (kinfo, f.apply k)
  | ILevel (kinfo, k) -> ILevel (kinfo, f.apply k)
  | ICheck_signature (kinfo, k) -> ICheck_signature (kinfo, f.apply k)
  | IHash_key (kinfo, k) -> IHash_key (kinfo, f.apply k)
  | IPack (kinfo, ty, k) -> IPack (kinfo, ty, f.apply k)
  | IUnpack (kinfo, ty, k) -> IUnpack (kinfo, ty, f.apply k)
  | IBlake2b (kinfo, k) -> IBlake2b (kinfo, f.apply k)
  | ISha256 (kinfo, k) -> ISha256 (kinfo, f.apply k)
  | ISha512 (kinfo, k) -> ISha512 (kinfo, f.apply k)
  | ISource (kinfo, k) -> ISource (kinfo, f.apply k)
  | ISender (kinfo, k) -> ISender (kinfo, f.apply k)
  | ISelf (kinfo, ty, s, k) -> ISelf (kinfo, ty, s, f.apply k)
  | ISelf_address (kinfo, k) -> ISelf_address (kinfo, f.apply k)
  | IAmount (kinfo, k) -> IAmount (kinfo, f.apply k)
  | ISapling_empty_state (kinfo, s, k) ->
      ISapling_empty_state (kinfo, s, f.apply k)
  | ISapling_verify_update (kinfo, k) ->
      ISapling_verify_update (kinfo, f.apply k)
  | IDig (kinfo, n, p, k) -> IDig (kinfo, n, p, f.apply k)
  | IDug (kinfo, n, p, k) -> IDug (kinfo, n, p, f.apply k)
  | IDipn (kinfo, n, p, k1, k2) -> IDipn (kinfo, n, p, f.apply k1, f.apply k2)
  | IDropn (kinfo, n, p, k) -> IDropn (kinfo, n, p, f.apply k)
  | IChainId (kinfo, k) -> IChainId (kinfo, f.apply k)
  | INever kinfo -> INever kinfo
  | IVoting_power (kinfo, k) -> IVoting_power (kinfo, f.apply k)
  | ITotal_voting_power (kinfo, k) -> ITotal_voting_power (kinfo, f.apply k)
  | IKeccak (kinfo, k) -> IKeccak (kinfo, f.apply k)
  | ISha3 (kinfo, k) -> ISha3 (kinfo, f.apply k)
  | IAdd_bls12_381_g1 (kinfo, k) -> IAdd_bls12_381_g1 (kinfo, f.apply k)
  | IAdd_bls12_381_g2 (kinfo, k) -> IAdd_bls12_381_g2 (kinfo, f.apply k)
  | IAdd_bls12_381_fr (kinfo, k) -> IAdd_bls12_381_fr (kinfo, f.apply k)
  | IMul_bls12_381_g1 (kinfo, k) -> IMul_bls12_381_g1 (kinfo, f.apply k)
  | IMul_bls12_381_g2 (kinfo, k) -> IMul_bls12_381_g2 (kinfo, f.apply k)
  | IMul_bls12_381_fr (kinfo, k) -> IMul_bls12_381_fr (kinfo, f.apply k)
  | IMul_bls12_381_z_fr (kinfo, k) -> IMul_bls12_381_z_fr (kinfo, f.apply k)
  | IMul_bls12_381_fr_z (kinfo, k) -> IMul_bls12_381_fr_z (kinfo, f.apply k)
  | IInt_bls12_381_fr (kinfo, k) -> IInt_bls12_381_fr (kinfo, f.apply k)
  | INeg_bls12_381_g1 (kinfo, k) -> INeg_bls12_381_g1 (kinfo, f.apply k)
  | INeg_bls12_381_g2 (kinfo, k) -> INeg_bls12_381_g2 (kinfo, f.apply k)
  | INeg_bls12_381_fr (kinfo, k) -> INeg_bls12_381_fr (kinfo, f.apply k)
  | IPairing_check_bls12_381 (kinfo, k) ->
      IPairing_check_bls12_381 (kinfo, f.apply k)
  | IComb (kinfo, n, p, k) -> IComb (kinfo, n, p, f.apply k)
  | IUncomb (kinfo, n, p, k) -> IUncomb (kinfo, n, p, f.apply k)
  | IComb_get (kinfo, n, p, k) -> IComb_get (kinfo, n, p, f.apply k)
  | IComb_set (kinfo, n, p, k) -> IComb_set (kinfo, n, p, f.apply k)
  | IDup_n (kinfo, n, p, k) -> IDup_n (kinfo, n, p, f.apply k)
  | ITicket (kinfo, k) -> ITicket (kinfo, f.apply k)
  | IRead_ticket (kinfo, k) -> IRead_ticket (kinfo, f.apply k)
  | ISplit_ticket (kinfo, k) -> ISplit_ticket (kinfo, f.apply k)
  | IJoin_tickets (kinfo, ty, k) -> IJoin_tickets (kinfo, ty, f.apply k)
  | IHalt kinfo -> IHalt kinfo
  | ILog (kinfo, event, logger, k) -> ILog (kinfo, event, logger, k)
  | IOpen_chest (kinfo, k) -> IOpen_chest (kinfo, f.apply k)

let ty_metadata : type a. a ty -> a ty_metadata = function
  | Unit_t meta -> meta
  | Never_t meta -> meta
  | Int_t meta -> meta
  | Nat_t meta -> meta
  | Signature_t meta -> meta
  | String_t meta -> meta
  | Bytes_t meta -> meta
  | Mutez_t meta -> meta
  | Bool_t meta -> meta
  | Key_hash_t meta -> meta
  | Key_t meta -> meta
  | Timestamp_t meta -> meta
  | Chain_id_t meta -> meta
  | Address_t meta -> meta
  | Pair_t (_, _, meta) -> meta
  | Union_t (_, _, meta) -> meta
  | Option_t (_, meta) -> meta
  | Lambda_t (_, _, meta) -> meta
  | List_t (_, meta) -> meta
  | Set_t (_, meta) -> meta
  | Map_t (_, _, meta) -> meta
  | Big_map_t (_, _, meta) -> meta
  | Ticket_t (_, meta) -> meta
  | Contract_t (_, meta) -> meta
  | Sapling_transaction_t (_, meta) -> meta
  | Sapling_state_t (_, meta) -> meta
  | Operation_t meta -> meta
  | Bls12_381_g1_t meta -> meta
  | Bls12_381_g2_t meta -> meta
  | Bls12_381_fr_t meta -> meta
  | Chest_t meta -> meta
  | Chest_key_t meta -> meta

let ty_size t = (ty_metadata t).size

let unit_t ~annot = Unit_t {annot; size = Type_size.one}

let int_t ~annot = Int_t {annot; size = Type_size.one}

let nat_t ~annot = Nat_t {annot; size = Type_size.one}

let signature_t ~annot = Signature_t {annot; size = Type_size.one}

let string_t ~annot = String_t {annot; size = Type_size.one}

let bytes_t ~annot = Bytes_t {annot; size = Type_size.one}

let mutez_t ~annot = Mutez_t {annot; size = Type_size.one}

let key_hash_t ~annot = Key_hash_t {annot; size = Type_size.one}

let key_t ~annot = Key_t {annot; size = Type_size.one}

let timestamp_t ~annot = Timestamp_t {annot; size = Type_size.one}

let address_t ~annot = Address_t {annot; size = Type_size.one}

let bool_t ~annot = Bool_t {annot; size = Type_size.one}

let pair_t loc (l, fannot_l, vannot_l) (r, fannot_r, vannot_r) ~annot =
  Type_size.compound2 loc (ty_size l) (ty_size r) >|? fun size ->
  Pair_t ((l, fannot_l, vannot_l), (r, fannot_r, vannot_r), {annot; size})

let union_t loc (l, fannot_l) (r, fannot_r) ~annot =
  Type_size.compound2 loc (ty_size l) (ty_size r) >|? fun size ->
  Union_t ((l, fannot_l), (r, fannot_r), {annot; size})

let union_bytes_bool_t =
  Union_t
    ( (bytes_t ~annot:None, None),
      (bool_t ~annot:None, None),
      {annot = None; size = Type_size.three} )

let lambda_t loc l r ~annot =
  Type_size.compound2 loc (ty_size l) (ty_size r) >|? fun size ->
  Lambda_t (l, r, {annot; size})

let option_t loc t ~annot =
  Type_size.compound1 loc (ty_size t) >|? fun size -> Option_t (t, {annot; size})

let option_string'_t meta =
  let {annot; size = _} = meta in
  Option_t (string_t ~annot, {annot = None; size = Type_size.two})

let option_bytes'_t meta =
  let {annot; size = _} = meta in
  Option_t (bytes_t ~annot, {annot = None; size = Type_size.two})

let option_nat_t =
  Option_t (nat_t ~annot:None, {annot = None; size = Type_size.two})

let option_pair_nat_nat_t =
  Option_t
    ( Pair_t
        ( (nat_t ~annot:None, None, None),
          (nat_t ~annot:None, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let option_pair_nat'_nat'_t meta =
  let {annot; size = _} = meta in
  Option_t
    ( Pair_t
        ( (nat_t ~annot, None, None),
          (nat_t ~annot, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let option_pair_nat_mutez'_t meta =
  let {annot; size = _} = meta in
  Option_t
    ( Pair_t
        ( (nat_t ~annot:None, None, None),
          (mutez_t ~annot, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let option_pair_mutez'_mutez'_t meta =
  let {annot; size = _} = meta in
  Option_t
    ( Pair_t
        ( (mutez_t ~annot, None, None),
          (mutez_t ~annot, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let option_pair_int'_nat_t meta =
  let {annot; size = _} = meta in
  Option_t
    ( Pair_t
        ( (int_t ~annot, None, None),
          (nat_t ~annot:None, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let option_pair_int_nat'_t meta =
  let {annot; size = _} = meta in
  Option_t
    ( Pair_t
        ( (int_t ~annot:None, None, None),
          (nat_t ~annot, None, None),
          {annot = None; size = Type_size.three} ),
      {annot = None; size = Type_size.four} )

let list_t loc t ~annot =
  Type_size.compound1 loc (ty_size t) >|? fun size -> List_t (t, {annot; size})

let operation_t ~annot = Operation_t {annot; size = Type_size.one}

let list_operation_t =
  List_t (operation_t ~annot:None, {annot = None; size = Type_size.two})

let set_t loc t ~annot =
  Type_size.compound1 loc (comparable_ty_size t) >|? fun size ->
  Set_t (t, {annot; size})

let map_t loc l r ~annot =
  Type_size.compound2 loc (comparable_ty_size l) (ty_size r) >|? fun size ->
  Map_t (l, r, {annot; size})

let big_map_t loc l r ~annot =
  Type_size.compound2 loc (comparable_ty_size l) (ty_size r) >|? fun size ->
  Big_map_t (l, r, {annot; size})

let contract_t loc t ~annot =
  Type_size.compound1 loc (ty_size t) >|? fun size ->
  Contract_t (t, {annot; size})

let contract_unit_t =
  Contract_t (unit_t ~annot:None, {annot = None; size = Type_size.two})

let sapling_transaction_t ~memo_size ~annot =
  Sapling_transaction_t (memo_size, {annot; size = Type_size.one})

let sapling_state_t ~memo_size ~annot =
  Sapling_state_t (memo_size, {annot; size = Type_size.one})

let chain_id_t ~annot = Chain_id_t {annot; size = Type_size.one}

let never_t ~annot = Never_t {annot; size = Type_size.one}

let bls12_381_g1_t ~annot = Bls12_381_g1_t {annot; size = Type_size.one}

let bls12_381_g2_t ~annot = Bls12_381_g2_t {annot; size = Type_size.one}

let bls12_381_fr_t ~annot = Bls12_381_fr_t {annot; size = Type_size.one}

let ticket_t loc t ~annot =
  Type_size.compound1 loc (comparable_ty_size t) >|? fun size ->
  Ticket_t (t, {annot; size})

let chest_key_t ~annot = Chest_key_t {annot; size = Type_size.one}

let chest_t ~annot = Chest_t {annot; size = Type_size.one}
