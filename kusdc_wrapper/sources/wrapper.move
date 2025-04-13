module kusdc_wrapper::wrapper {
    use kamo::yield_object::{YieldObject};
    use kamo::amm::{Market, SellYoBorrowPt, BuyYoBorrowSy, Self, LP};
    use kamo::sy_tokenization::{Registry, Factory, Self};
    use kusdc::kusdc::{KUSDC};
    use kusdc::system::{Self, System};
    use sui::coin::{Coin, TreasuryCap};
    use sui::clock::{Clock};
    use kusdc_wrapper::PT::{PT};
    use legato_math::fixed_point64::{FixedPoint64, Self};

    public struct State has key, store {
        id: UID,
        market: Market<PT, KUSDC>,
        registry: Registry<PT, KUSDC>,
    }

    /*
        Only be called once because TreasuryCap<PT> only be created once.
    */
    public fun create_new_state(factory: &mut Factory, treasury: TreasuryCap<PT>, expiry: u64, scalar_root: FixedPoint64, initial_anchor: FixedPoint64, ln_fee_rate_root: FixedPoint64, clock: &Clock, ctx: &mut TxContext) {
        let market = amm::create_new_market<PT, KUSDC>(expiry, scalar_root, initial_anchor, ln_fee_rate_root, clock, ctx);
        let registry = sy_tokenization::create_new_registry(factory, treasury, ctx);
        let state = State {
            id: object::new(ctx),
            market,
            registry,
        };
        transfer::share_object(state);
    }

    public fun get_exchange_rate(system: &System): FixedPoint64 {
        let exchange_rate = system::get_exchange_rate(system);
        fixed_point64::create_from_rational(exchange_rate as u128, 1000000)
    }
    
    public fun add_liquidity(state: &mut State, pt_coin: Coin<PT>, sy_coin: Coin<KUSDC>, system: &System, clock: &Clock, ctx: &mut TxContext): Coin<LP<PT, KUSDC>> {
        amm::add_liquidity(&mut state.market, pt_coin, sy_coin, get_exchange_rate(system), clock, ctx)
    }
    public fun remove_liquidity(state: &mut State, lp: Coin<LP<PT, KUSDC>>, ctx: &mut TxContext): (Coin<PT>, Coin<KUSDC>) {
        amm::remove_liquidity(&mut state.market, lp, ctx)
    }
    public fun swap_exact_pt_for_sy(state: &mut State, pt_coin: Coin<PT>, system: &System, clock: &Clock, ctx: &mut TxContext): Coin<KUSDC> {
        amm::swap_exact_pt_for_sy(&mut state.market, get_exchange_rate(system), pt_coin, clock, ctx)
    }

    public fun swap_sy_for_exact_pt(state: &mut State, sy_coin: Coin<KUSDC>, system: &System, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (Coin<KUSDC>, Coin<PT>) {
        amm::swap_sy_for_exact_pt(&mut state.market, get_exchange_rate(system), sy_coin, pt_amount, clock, ctx)
    }

    public fun swap_sy_for_exact_pt_with_hot_potato(state: &mut State, hot_potato: SellYoBorrowPt<PT, KUSDC>, sy_coin: Coin<KUSDC>, system: &System, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (Coin<KUSDC>, Coin<PT>, SellYoBorrowPt<PT, KUSDC>) {
        amm::swap_sy_for_exact_pt_with_hot_potato(&mut state.market, hot_potato, get_exchange_rate(system), sy_coin, pt_amount, clock, ctx)
    }

    public fun swap_exact_pt_for_sy_with_hot_potato(state: &mut State, hot_potato: BuyYoBorrowSy<PT, KUSDC>, pt_coin: Coin<PT>, system: &System, clock: &Clock, ctx: &mut TxContext): (Coin<KUSDC>, BuyYoBorrowSy<PT, KUSDC>) {
        amm::swap_exact_pt_for_sy_with_hot_potato(&mut state.market, hot_potato, get_exchange_rate(system), pt_coin, clock, ctx)
    }

    public fun mint(state: &mut State, kusdc_coin_in: Coin<KUSDC>, system: &System, clock: &Clock, ctx: &mut TxContext): (Coin<PT>, YieldObject<PT, KUSDC>) {
        sy_tokenization::mint(&mut state.registry, &state.market, kusdc_coin_in, get_exchange_rate(system), clock, ctx)
    }

    public fun split(state: &mut State, yield_object: &mut YieldObject<PT, KUSDC>, amount: u64, ctx: &mut TxContext): YieldObject<PT, KUSDC> {
        sy_tokenization::split(&state.market, yield_object, amount, ctx)
    }

    public fun merge(state: &mut State, self: &mut YieldObject<PT, KUSDC>, yield_object: YieldObject<PT, KUSDC>, system: &System) {
        sy_tokenization::merge(&state.market, self, yield_object, get_exchange_rate(system))
    }

    public fun redeem_before_maturity(state: &mut State, pt_coin_in: Coin<PT>, yield_object: YieldObject<PT, KUSDC>, system: &System, clock: &Clock, ctx: &mut TxContext): Coin<KUSDC> {
        sy_tokenization::redeem_before_maturity(&mut state.registry, &state.market, pt_coin_in, yield_object, get_exchange_rate(system), clock, ctx)
    }
  
    public fun redeem_after_maturity(state: &mut State, pt_coin_in: Coin<PT>, system: &System, clock: &Clock, ctx: &mut TxContext): Coin<KUSDC> {
        sy_tokenization::redeem_after_maturity(&mut state.registry, &state.market, pt_coin_in, get_exchange_rate(system), clock, ctx)
    }

    public fun earn_interest(state: &State, yield_object: &mut YieldObject<PT, KUSDC>, system: &System, clock: &Clock) {
        sy_tokenization::earn_interest<PT, KUSDC>(&state.market, yield_object, get_exchange_rate(system), clock)
    }

    public fun claim_interest(state: &mut State, yield_object: &mut YieldObject<PT, KUSDC>, clock: &Clock, ctx: &mut TxContext): Coin<KUSDC> {
        sy_tokenization::claim_interest(&mut state.registry, &state.market, yield_object, clock, ctx)
    }

    public fun borrow_pt(state: &mut State, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (SellYoBorrowPt<PT, KUSDC>, Coin<PT>) {
        amm::borrow_pt(&mut state.market, pt_amount, clock, ctx)
    }

    public fun refund_pt(state: &mut State, hot_potato: SellYoBorrowPt<PT, KUSDC>, pt_coin: Coin<PT>) {
        amm::refund_pt(&mut state.market, hot_potato, pt_coin);
    }

    public fun borrow_sy(state: &mut State, sy_amount: u64, clock: &Clock, ctx: &mut TxContext): (BuyYoBorrowSy<PT, KUSDC>, Coin<KUSDC>) {
        amm::borrow_sy(&mut state.market, sy_amount, clock, ctx)
    }

    public fun refund_sy(state: &mut State, hot_potato: BuyYoBorrowSy<PT, KUSDC>, sy_coin: Coin<KUSDC>) {
        amm::refund_sy(&mut state.market, hot_potato, sy_coin);
    }

    public fun claim_fee(state: &mut State, ctx: &mut TxContext): Coin<KUSDC> {
        amm::claim_fee<PT, KUSDC>(&mut state.market, ctx)
    }
}