(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(** Is the contract eligible to delegation ? *)
val is_delegatable:
  Raw_context.t -> Contract_repr.t -> bool tzresult Lwt.t

(** Allow to register a delegate when creating an account. *)
val init:
  Raw_context.t -> Contract_repr.t -> Ed25519.Public_key_hash.t ->
  Raw_context.t tzresult Lwt.t

(** Cleanup delegation when deleting a contract. *)
val remove:
  Raw_context.t -> Contract_repr.t -> Raw_context.t tzresult Lwt.t

(** Reading the current delegate of a contract. *)
val get:
  Raw_context.t -> Contract_repr.t ->
  Ed25519.Public_key_hash.t option tzresult Lwt.t

(** Updating the delegate of a contract.

    When calling this function on an "implicit contract" this function
    fails, unless when the registred delegate is the contract manager.
    In the that case, the manager is now registred as a delegate. One
    cannot unregister a delegate for now. The associate contract is
    now 'undeletable'. *)
val set:
  Raw_context.t -> Contract_repr.t -> Ed25519.Public_key_hash.t option ->
  Raw_context.t tzresult Lwt.t

type error +=
  | Non_delegatable_contract of Contract_repr.contract (* `Permanent *)

(** Iterate on all registred delegates. *)
val fold:
  Raw_context.t ->
  init:'a ->
  f:(Ed25519.Public_key_hash.t -> 'a -> 'a Lwt.t) -> 'a Lwt.t

(** List all registred delegates. *)
val list: Raw_context.t -> Ed25519.Public_key_hash.t list Lwt.t

(** Various functions to 'freeze' tokens.  A frozen 'bond' keeps its
    associated rolls. When frozen, 'fees' may trigger new rolls
    allocation. Rewards won't trigger new rolls allocation until
    unfrozen. *)
val freeze_bond:
  Raw_context.t -> Ed25519.Public_key_hash.t -> Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

val freeze_fees:
  Raw_context.t -> Ed25519.Public_key_hash.t -> Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

val freeze_rewards:
  Raw_context.t -> Ed25519.Public_key_hash.t -> Tez_repr.t ->
  Raw_context.t tzresult Lwt.t

(** Trigger the context maintenance at the end of cycle 'n', i.e.:
    unfroze bond/fees/rewards from 'n - preserved_cycle' ; punish the
    provided unrevealed seeds (tipically seed from from cycle 'n -
    1'). *)
val cycle_end:
  Raw_context.t -> Cycle_repr.t -> Nonce_storage.unrevealed list ->
  Raw_context.t tzresult Lwt.t

(** Burn all then frozen bond/fees/rewards for a delegate at a given
    cycle. Returns the burned amount. *)
val punish:
  Raw_context.t -> Ed25519.Public_key_hash.t -> Cycle_repr.t ->
  (Raw_context.t * Tez_repr.t) tzresult Lwt.t

(** Has the given key some frozen tokens in its implicit contract? *)
val has_frozen_balance:
  Raw_context.t -> Ed25519.Public_key_hash.t -> Cycle_repr.t ->
  bool tzresult Lwt.t

(** Returns the amount of frozen tokens associated to a given key. *)
val frozen_balance:
  Raw_context.t -> Ed25519.Public_key_hash.t ->
  Tez_repr.t tzresult Lwt.t

(** Returns the full 'balance' of the implicit contract associated to
    a given key, i.e. the sum of the spendable balance and of the
    frozen balance. *)
val full_balance:
  Raw_context.t -> Ed25519.Public_key_hash.t ->
  Tez_repr.t tzresult Lwt.t
