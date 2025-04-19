module kusdc::system {
    use kusdc::kusdc::{KUSDC};
    use usdc::usdc::{USDC};
    use sui::balance::{Balance, Self};
    use sui::coin::{Coin, Self, TreasuryCap};

    public struct System has key {
        id: UID,
        balance_usdc: Balance<USDC>,
        total_kusdc_minted: u64,
    }

    fun init(ctx: &mut TxContext) {
        let system = System {
            id: object::new(ctx),
            balance_usdc: balance::zero(),
            total_kusdc_minted: 0,
        };
        transfer::share_object(system);
    }

    public fun mint(system: &mut System, cap: &mut TreasuryCap<KUSDC>, coin: Coin<USDC>, ctx: &mut TxContext): Coin<KUSDC> {
        let amount = coin::value(&coin);
        let exchange_rate = get_usdc_to_kusdc_exchange_rate(system);
        let kusdc_amount = amount * exchange_rate / 1_000_000;
        system.total_kusdc_minted = system.total_kusdc_minted + kusdc_amount;
        coin::put(&mut system.balance_usdc, coin);
        coin::mint<KUSDC>(cap, kusdc_amount, ctx)
    }

    public fun put_usdc(system: &mut System, coin: Coin<USDC>) {
        coin::put(&mut system.balance_usdc, coin);
    }

    public fun first_put_usdc(system: &mut System, coin: Coin<USDC>) {
        let value = coin::value(&coin);
        put_usdc(system, coin);
        system.total_kusdc_minted = system.total_kusdc_minted + value;
    }

    public fun get_kusdc_to_usdc_exchange_rate(system: &System): u64 {
        let total_usdc_supply = balance::value(&system.balance_usdc);
        let total_kusdc_minted = system.total_kusdc_minted;
        total_usdc_supply * 1_000_000 / total_kusdc_minted
    }

    public fun get_usdc_to_kusdc_exchange_rate(system: &System): u64 {
        let total_usdc_supply = balance::value(&system.balance_usdc);
        let total_kusdc_minted = system.total_kusdc_minted;
        total_kusdc_minted * 1_000_000 / total_usdc_supply
    }

    public fun faucet(cap: &mut TreasuryCap<KUSDC>, amount: u64, ctx: &mut TxContext): Coin<KUSDC> {
        coin::mint<KUSDC>(cap, amount, ctx)
    }
}