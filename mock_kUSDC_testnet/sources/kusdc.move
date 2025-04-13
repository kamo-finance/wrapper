module kusdc::kusdc {
    use usdc::usdc::{USDC};
    use sui::coin::{Self};

    public struct KUSDC has drop {}
    const ICON_URL: vector<u8> = b"https://www.circle.com/hubfs/Brand/USDC/USDC_icon_32x32.png";

    fun init(witness: KUSDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<KUSDC>(
            witness,
            6,               // decimals
            b"kUSDC",         // symbol
            b"kUSDC",         // name
            b"kUSDC",         // description
            option::none(),
            ctx
        );
        transfer::public_share_object(treasury_cap);
        transfer::public_freeze_object(metadata);
    }
}