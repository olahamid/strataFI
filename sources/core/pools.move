// ============================================
// StrataFi Pool maker Module
// 
// ============================================

module stratafi::pools {
    use stratafi::pool_tokens;
    use stratafi::math;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::fungible_asset::Metadata;
    use aptos_std::table::{Self, Table};
    use std::string::String;
    use aptos_framework::object::Object;
    use std::signer;

    const TRANCHE_SENIOR: u8 = 0;
    const TRANCHE_MEZZ: u8 = 1;
    const TRANCHE_JUNIOR: u8 = 2;

    const STATUS_PENDING: u8 = 0;
    const STATUS_ACTIVE: u8 = 1;
    const STATUS_PAUSED: u8 = 2;
    const STATUS_CLOSED: u8 = 3;

    // =========================
    // STRUCTS
    // =========================
    struct Pool has store {
        pool_id: u64,
        assetCreator: address,

        // ASSET INFORMATION 
        asset_type: String, // TODO maybe different ID for differnt types 
        total_value: u64, // eg to raise 10 M dollars

        // Pricing configuration
        use_bonding_curve:bool,
        fixed_price: u64,

        // Bounding curve state
        usdc_reserve: u64,   // USDC in pool 
        token_reserve: u64,  // virtual token reserve for curve
        fee_numerator: u64,
        fee_denominator: u64,

        // Tranches
        senior_tranche: Tranche,
        mezz_tranche: Tranche,
        junior_tranche: Tranche,

        // Tresury 
        usdc_balance: u64,

        // state
        status: u8,
        created_at: u64,

    }

    struct Tranche has store, copy, drop {
        tranche_type: u8,
        token_metadata: Object<Metadata>,
        allocation_percentage: u64,
        target_raise: u64,
        current_raise: u64,
        expected_apy: u64,
    } 

    struct PoolRegistry has key {
        pools: Table<u64, Pool>,
        pool_count: u64,
    }

    fun init_module(admin: &signer) {
        move_to(admin, PoolRegistry{
            pools: table::new(),
            pool_count: 0,
        });
    }

}

