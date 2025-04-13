module kusdc_wrapper::PT {
  use sui::coin::{Self, TreasuryCap};
  public struct PT has drop {}

  fun init(otw: PT, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
      otw,
      6,
      b"PT",
      b"PT for kUSDC",
      b"Principal Token for kUSDC",
      option::none(),
      ctx,
		);
    transfer::public_freeze_object(metadata);
    transfer::public_transfer<TreasuryCap<PT>>(treasury, ctx.sender());
  }
}