module hasui_wrapper::wrapper {
    use kamo::yield_object::{YieldObject};
    use kamo::amm::{Market, SellYoBorrowPt, BuyYoBorrowSy, Self, LP};
    use kamo::sy_tokenization::{Registry, Factory, Self};
    use haedal::hasui::{HASUI};
    use haedal::staking::{Staking, Self};
    use sui::coin::{Coin, TreasuryCap};
    use sui::clock::{Clock};
    use hasui_wrapper::PT::{PT};
    use legato_math::fixed_point64::{FixedPoint64, Self};

    public struct State has key, store {
        id: UID,
        market: Market<PT, HASUI>,
        registry: Registry<PT, HASUI>,
    }

    /*
        Only be called once because TreasuryCap<PT> only be created once.
    */
    public fun create_new_state(factory: &mut Factory, treasury: TreasuryCap<PT>, expiry: u64, scalar_root: FixedPoint64, initial_anchor: FixedPoint64, ln_fee_rate_root: FixedPoint64, clock: &Clock, ctx: &mut TxContext) {
        let market = amm::create_new_market<PT, HASUI>(expiry, scalar_root, initial_anchor, ln_fee_rate_root, clock, ctx);
        let registry = sy_tokenization::create_new_registry(factory, treasury, ctx);
        let state = State {
            id: object::new(ctx),
            market,
            registry,
        };
        transfer::share_object(state);
    }

    public fun get_exchange_rate(staking: &Staking): FixedPoint64 {
        let exchange_rate = staking::get_exchange_rate(staking);
        fixed_point64::create_from_rational(exchange_rate as u128, 1000000)
    }
    
    public fun add_liquidity(state: &mut State, pt_coin: Coin<PT>, sy_coin: Coin<HASUI>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): Coin<LP<PT, HASUI>> {
        amm::add_liquidity(&mut state.market, pt_coin, sy_coin, get_exchange_rate(staking), clock, ctx)
    }
    public fun remove_liquidity(state: &mut State, lp: Coin<LP<PT, HASUI>>, ctx: &mut TxContext): (Coin<PT>, Coin<HASUI>) {
        amm::remove_liquidity(&mut state.market, lp, ctx)
    }
    public fun swap_exact_pt_for_sy(state: &mut State, pt_coin: Coin<PT>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): Coin<HASUI> {
        amm::swap_exact_pt_for_sy(&mut state.market, get_exchange_rate(staking), pt_coin, clock, ctx)
    }

    public fun swap_sy_for_exact_pt(state: &mut State, sy_coin: Coin<HASUI>, staking: &Staking, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (Coin<HASUI>, Coin<PT>) {
        amm::swap_sy_for_exact_pt(&mut state.market, get_exchange_rate(staking), sy_coin, pt_amount, clock, ctx)
    }

    public fun swap_sy_for_exact_pt_with_hot_potato(state: &mut State, hot_potato: SellYoBorrowPt<PT, HASUI>, sy_coin: Coin<HASUI>, staking: &Staking, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (Coin<HASUI>, Coin<PT>, SellYoBorrowPt<PT, HASUI>) {
        amm::swap_sy_for_exact_pt_with_hot_potato(&mut state.market, hot_potato, get_exchange_rate(staking), sy_coin, pt_amount, clock, ctx)
    }

    public fun swap_exact_pt_for_sy_with_hot_potato(state: &mut State, hot_potato: BuyYoBorrowSy<PT, HASUI>, pt_coin: Coin<PT>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): (Coin<HASUI>, BuyYoBorrowSy<PT, HASUI>) {
        amm::swap_exact_pt_for_sy_with_hot_potato(&mut state.market, hot_potato, get_exchange_rate(staking), pt_coin, clock, ctx)
    }

    public fun mint(state: &mut State, hasui_coin_in: Coin<HASUI>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): (Coin<PT>, YieldObject<PT, HASUI>) {
        sy_tokenization::mint(&mut state.registry, &state.market, hasui_coin_in, get_exchange_rate(staking), clock, ctx)
    }

    public fun split(state: &mut State, yield_object: &mut YieldObject<PT, HASUI>, amount: u64, ctx: &mut TxContext): YieldObject<PT, HASUI> {
        sy_tokenization::split(&state.market, yield_object, amount, ctx)
    }

    public fun merge(state: &mut State, self: &mut YieldObject<PT, HASUI>, yield_object: YieldObject<PT, HASUI>, staking: &Staking) {
        sy_tokenization::merge(&state.market, self, yield_object, get_exchange_rate(staking))
    }

    public fun redeem_before_maturity(state: &mut State, pt_coin_in: Coin<PT>, yield_object: YieldObject<PT, HASUI>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): Coin<HASUI> {
        sy_tokenization::redeem_before_maturity(&mut state.registry, &state.market, pt_coin_in, yield_object, get_exchange_rate(staking), clock, ctx)
    }
  
    public fun redeem_after_maturity(state: &mut State, pt_coin_in: Coin<PT>, staking: &Staking, clock: &Clock, ctx: &mut TxContext): Coin<HASUI> {
        sy_tokenization::redeem_after_maturity(&mut state.registry, &state.market, pt_coin_in, get_exchange_rate(staking), clock, ctx)
    }

    public fun earn_interest(state: &State, yield_object: &mut YieldObject<PT, HASUI>, staking: &Staking, clock: &Clock) {
        sy_tokenization::earn_interest<PT, HASUI>(&state.market, yield_object, get_exchange_rate(staking), clock)
    }

    public fun claim_interest(state: &mut State, yield_object: &mut YieldObject<PT, HASUI>, clock: &Clock, ctx: &mut TxContext): Coin<HASUI> {
        sy_tokenization::claim_interest(&mut state.registry, &state.market, yield_object, clock, ctx)
    }

    public fun borrow_pt(state: &mut State, pt_amount: u64, clock: &Clock, ctx: &mut TxContext): (SellYoBorrowPt<PT, HASUI>, Coin<PT>) {
        amm::borrow_pt(&mut state.market, pt_amount, clock, ctx)
    }

    public fun refund_pt(state: &mut State, hot_potato: SellYoBorrowPt<PT, HASUI>, pt_coin: Coin<PT>) {
        amm::refund_pt(&mut state.market, hot_potato, pt_coin);
    }

    public fun borrow_sy(state: &mut State, sy_amount: u64, clock: &Clock, ctx: &mut TxContext): (BuyYoBorrowSy<PT, HASUI>, Coin<HASUI>) {
        amm::borrow_sy(&mut state.market, sy_amount, clock, ctx)
    }

    public fun refund_sy(state: &mut State, hot_potato: BuyYoBorrowSy<PT, HASUI>, sy_coin: Coin<HASUI>) {
        amm::refund_sy(&mut state.market, hot_potato, sy_coin);
    }

    public fun claim_fee(state: &mut State, ctx: &mut TxContext): Coin<HASUI> {
        amm::claim_fee<PT, HASUI>(&mut state.market, ctx)
    }
}