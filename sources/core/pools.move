// ==========================// 
// StrataFi Pool maker Module//
// ==========================// 

// @fixME add dfferent tranche types and their handling
// @fixME add events
// vulnerability issue of having all pools under one registry, DoS attack possible
// @fixME add more validations and checks especially around pool creation of a pool
// @fixME solve the issue and read more on how move handles decimal devisions if it's similar to solidity 
// @fixME add helper function to get more pool buyable tokens

module stratafi::pools {
    use stratafi::pool_tokens;
    use stratafi::math;
    use aptos_framework::coin::{Self};
    //use aptos_framework::timestamp;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_std::table::{Self, Table};
    use std::string::{Self, String};
    use aptos_framework::object::{Self, Object};
    use std::signer;
    use stratafi::STFI::{STFI};
    
    
    // =========================
    // ERRORS
    // =========================
    /// all error code follow a binary schema 100 - 200
    /// @error E_POOL_NOT_FOUND: Pool not found error
    const E_POOL_NOT_FOUND: u64 = 200;
    /// @error E_POOL_NOT_ACTIVE: Pool not active error
    const E_POOL_NOT_ACTIVE: u64 = 210;
    /// @error E_INVALID_ALLOCATION: Invalid allocation error
    const E_INVALID_ALLOCATION: u64 = 220;
    /// @error E_INVALID_TRANCHE: Invalid tranche error
    const E_INVALID_TRANCHE: u64 = 230;
    // =========================
    // CONSTANTS
    // =========================
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
    struct Pool has store, copy, drop {
        pool_id: u64,
        asset_Creator: address,

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
        // store the PoolRegistry resource under admin
        move_to(admin, PoolRegistry{
            pools: table::new(),
            pool_count: 0,
        });
    }

    public entry fun create_pool(
        asset_creator: &signer, // who is doing the asset creations 
        asset_type: String, // what asset are backing this 
        total_value: u64, // total value to be raised
        use_bonding_curve: bool, // fixed price or bonding curve
        fixed_price: u64, // if fixed price, what is it
        initial_token_reserve: u64, // initial virtual token reserve for bonding curve
        fee_numerator: u64, // fee numerator for bonding curve
        fee_denominator: u64, // fee denominator for bonding curve has to be 10000
    ) acquires PoolRegistry {
        // TODO CHECKS 
        // get the registry reference in a mutable way
        let creator_addr = signer::address_of(asset_creator);
        let registry = borrow_global_mut<PoolRegistry>(@stratafi);

        // get the pool Id, increase count 
        let pool_id = registry.pool_count;
        registry.pool_count += 1;

        let created_time = aptos_framework::timestamp::now_seconds();

        let empty_tranche = Tranche {
            tranche_type: 0,
            token_metadata: object::address_to_object(@0x0), // TODO i dont know how to handle this right, will do more research for better way
            allocation_percentage: 0,
            target_raise: 0,
            current_raise: 0,
            expected_apy: 0,
        };

        let new_pool = Pool {
            pool_id,
            asset_Creator: creator_addr,
            asset_type,
            total_value,
            use_bonding_curve,
            fixed_price,
            usdc_reserve: 0,
            token_reserve: initial_token_reserve,
            fee_numerator,
            fee_denominator,

            senior_tranche: empty_tranche,
            mezz_tranche: empty_tranche,
            junior_tranche: empty_tranche,

            usdc_balance: 0,

            status: STATUS_PENDING,
            created_at: created_time,
        };
        // fill up the map like in sol
        registry.pools.add(pool_id, new_pool);
    }

    public entry fun securitize_pool(
        asset_creator: &signer,
        pool_id: u64,
        senior_allocation: u64,
        mezz_allocation: u64,
        junior_allocation: u64,
        senior_target: u64,
        mezz_target: u64,
        junior_target: u64,
        senior_apy: u64,
        mezz_apy: u64,
        junior_apy: u64,
    ) acquires PoolRegistry {
        //TODO add CREATOR Checks
        
        let registry = borrow_global_mut<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);
        let pool = registry.pools.borrow_mut(pool_id);

        assert!(pool.status == STATUS_PENDING, E_POOL_NOT_ACTIVE);
        // VALIDATE allocation to add up to 100%
        assert!(senior_allocation + mezz_allocation + junior_allocation == 10000, E_INVALID_ALLOCATION);

        // 
        let senior_token = pool_tokens::create_pool_token(
            asset_creator,
            pool_id,
            TRANCHE_SENIOR,
            string::utf8(b"Pool"), // TODO concatenate pool id
            string::utf8(b"PILS"), // TODO concatinate the dynmic symbol to pool
        );

        let mezz_token = pool_tokens::create_pool_token(
            asset_creator,
            pool_id,
            TRANCHE_MEZZ,
            string::utf8(b"Pool"), // TODO concatenate pool id
            string::utf8(b"PILS"), // TODO concatinate the dynmic symbol to pool
        );

        let junior_token = pool_tokens::create_pool_token(
            asset_creator,
            pool_id,
            TRANCHE_JUNIOR,
            string::utf8(b"Pool"), // TODO concatenate pool id
            string::utf8(b"PILS"), // TODO concatinate the dynmic symbol to pool
        );
        let senior_tranche = Tranche {
            tranche_type: TRANCHE_SENIOR,
            token_metadata: senior_token,
            allocation_percentage: senior_allocation,
            target_raise: senior_target,
            current_raise: 0,
            expected_apy: senior_apy,
        };

        pool.senior_tranche = senior_tranche;
        let mezz_tranche = Tranche {
            tranche_type: TRANCHE_MEZZ,
            token_metadata: mezz_token,
            allocation_percentage: mezz_allocation,
            target_raise: mezz_target,
            current_raise: 0,
            expected_apy: mezz_apy,
        };
        pool.mezz_tranche = mezz_tranche;

        let junior_tranche = Tranche {
            tranche_type: TRANCHE_JUNIOR,
            token_metadata: junior_token,
            allocation_percentage: junior_allocation,
            target_raise: junior_target,
            current_raise: 0,
            expected_apy: junior_apy,
        };
        pool.junior_tranche = junior_tranche;

        // set pool to active
        pool.status = STATUS_ACTIVE;
    }

    public entry fun invest_fixed_price(
        investor: &signer,
        pool_id: u64,
        tranche_type: u8,
        usdc_amount: u64,
    ) acquires PoolRegistry {
        // get the pool registry
        let registry = borrow_global_mut<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);
        let pool = registry.pools.borrow_mut(pool_id);

        // asssert validate pool state and check that bounding curve isnt picked
        assert!(pool.status == STATUS_ACTIVE, E_POOL_NOT_ACTIVE);
        assert!(!pool.use_bonding_curve, E_INVALID_ALLOCATION);

        let fixed_price = pool.fixed_price;
        assert!(fixed_price > 0, E_INVALID_ALLOCATION);

        let tranche = get_tranche_mut(pool, tranche_type);

        // computet the token to be minted. we can use formula usdc_amount/ pool.fixed_price
        let token_amount = usdc_amount / fixed_price;
        
        // check that the investors does go beyond the target raise
        let new_raise = tranche.current_raise + usdc_amount;
        assert!(new_raise <= tranche.target_raise, E_INVALID_ALLOCATION);

        let token_metadata = tranche.token_metadata;
        let investor_addr = signer::address_of(investor);
        // TODO allow investor to be a able to buy with different tokens later on
        let payment = coin::withdraw<STFI>(investor, usdc_amount);

        // for now we will destroy the STFI, later we will hold in pool treasury
        // TODO transfer to treasury OR create a new VAULT module to handle this
        coin::destroy_zero(payment);

        tranche.current_raise = new_raise;
        // update the state 
        pool.usdc_balance += usdc_amount;

        pool_tokens::mint_pool_tokens(
            token_metadata,
            investor_addr,
            token_amount,
        );

        // EMIT IT all later
    }   

    entry public fun invest_bonding_curve(
        investor: &signer,
        pool_id: u64,
        tranche_type: u8,
        usdc_amount: u64,
    ) acquires PoolRegistry {
        // get the pool registry
        let registry = borrow_global_mut<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);
        let pool = registry.pools.borrow_mut(pool_id);

        // asssert validate pool state and check that bounding curve isnt picked
        assert!(pool.status == STATUS_ACTIVE, E_POOL_NOT_ACTIVE);
        assert!(pool.use_bonding_curve, E_INVALID_ALLOCATION);

        let fee_numerator = pool.fee_numerator;
        let fee_denominator = pool.fee_denominator;
        let usdc_reserve = pool.usdc_reserve;
        let token_reserve = pool.token_reserve;

        let tranche = get_tranche_mut(pool, tranche_type);

        let token_metadata = tranche.token_metadata;
        // compute the amount of pool token to be minted using bonding curve math
        // TODO: implement bonding curve calculation using math module functions
        let fee = math::set_fraction(fee_numerator, fee_denominator);
        let token_amount = math::get_amount_out(
            usdc_amount,
            usdc_reserve,
            token_reserve,
            fee
        );

        let new_raise = tranche.current_raise + usdc_amount;
        // check that the investors does not go beyond the target raise
        assert!(new_raise <= tranche.target_raise, E_INVALID_ALLOCATION);

        let investor_addr = signer::address_of(investor);
        // TODO allow investor to be a able to buy with different tokens later on
        let payment = coin::withdraw<STFI>(investor, usdc_amount);

        // for now we will destroy the STFI, later we will hold in pool treasury
        // TODO transfer to treasury OR create a new VAULT module to handle this
        coin::destroy_zero(payment);

        tranche.current_raise = new_raise;
        // update the states
        pool.usdc_balance += usdc_amount;
        pool.usdc_reserve += usdc_amount;
        pool.token_reserve -= token_amount;

        pool_tokens::mint_pool_tokens(
            token_metadata,
            investor_addr,
            token_amount,
        );

        // EMIT IT all later    
    }


    fun get_tranche_mut(pool: &mut Pool, tranche_type: u8): &mut Tranche {
        if (tranche_type == TRANCHE_SENIOR) {
            &mut pool.senior_tranche
        } else if (tranche_type == TRANCHE_MEZZ) {
            &mut pool.mezz_tranche
        }  else if (tranche_type == TRANCHE_JUNIOR) {
            &mut pool.junior_tranche
        }
            else {
                abort E_INVALID_TRANCHE
        }
    }

    #[view]
    /// Get specific pool information
    /// @param pool_id - Which pool
    /// @return Pool struct
    public fun get_pool_info(pool_id: u64): (u64, address, String, u64, u8, u64) acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);

        let pool = registry.pools.borrow(pool_id);
        (
            pool.pool_id,
            pool.asset_Creator,
            pool.asset_type,
            pool.total_value,
            pool.status,
            pool.usdc_balance
        )
    }

    #[view]
    /// Get specific tranche information
    /// @param pool_id - Which pool
    /// @param tranche_type - Which tranche (0=Senior, 1=Mezz, 2=Junior)
    /// @return Tranche struct
    public fun get_tranche(pool_id: u64, tranche_type: u8): Tranche acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);
        let pool = registry.pools.borrow(pool_id);

        if (tranche_type == TRANCHE_SENIOR) {
            pool.senior_tranche
        } else if (tranche_type == TRANCHE_MEZZ) {
            pool.mezz_tranche
        } else if (tranche_type == TRANCHE_JUNIOR) {
            pool.junior_tranche
        } else {
            abort E_INVALID_TRANCHE
        }
    }

    #[view]
    /// Get total number of pools created
    /// @return Total pool count
    public fun get_pool_count(): u64 acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@stratafi);
        registry.pool_count
    }

    #[view]
    /// Check if a pool exists
    /// @param pool_id - Pool to check
    /// @return true if exists, false otherwise
    public fun pool_exists(pool_id: u64): bool acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@stratafi);
        registry.pools.contains(pool_id)
    }

    #[view]
    /// Get pool status
    /// @param pool_id - Which pool
    /// @return Status code (0=Pending, 1=Active, 2=Paused, 3=Closed)
    public fun get_pool_status(pool_id: u64): u8 acquires PoolRegistry {
        let registry = borrow_global<PoolRegistry>(@stratafi);
        assert!(registry.pools.contains(pool_id), E_POOL_NOT_FOUND);
        let pool = registry.pools.borrow(pool_id);
        pool.status
    }


}

