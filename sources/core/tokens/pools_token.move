// ============================================
// StrataFi Pool Token Factory
// Creates fungible asset tokens for each tranche
// ============================================

module stratafi::pool_tokens {



    // core Aptos frameWork 
    use std::string::{Self, String};
    use std::option;
    use aptos_framework::fungible_asset::{Self, MintRef, BurnRef, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;

    
    // =========================
    // ERRORS
    // =========================
    // all error code follow a binary schema 200 - 300
    /// @error E_POOL_TOKEN_ALREADY_EXISTS: Pool token already exists error
    const  E_POOL_TOKEN_ALREADY_EXISTS: u64 = 11001000;
    /// @error E_INVALID_TRANCHE_TYPE: Invalid tranche type error
    const E_INVALID_TRANCHE_TYPE: u64 = 11001001;
    /// @error E_MATH_ZERO_VALUE: Zero value error
    const E_MATH_ZERO_VALUE: u64 = 11001010;
    /// @error E_NOT_AUTHORIZED: Not authorized error
    const E_NOT_AUTHORIZED: u64 = 11001011;

    // =========================
    // CONSTANTS
    // =========================
    
    // Tranche types
    const TRANCHE_SENIOR: u8 = 0;
    const TRANCHE_MEZZ: u8 = 1;
    const TRANCHE_JUNIOR: u8 = 2;
    
    // =========================
    // STRUCTS
    // =========================
    // give admin minting and burning capabilities
    struct Pool_Token_Capabilities has key {
        mint_cap: MintRef,
        burn_cap: BurnRef,
    }

    // register each pool token under its own resource
    struct Token_Registry has key {

    }

    fun init_module(strataFi_admin: &signer) {
        // register the Token_Registry resource under the admin's account
        move_to(strataFi_admin, Token_Registry {});
    }

    public fun create_pool_token(
        creator: &signer,
        pool_id: u64,
        tranche_type: u8,
        name: String,
        symbol: String,
    ): Object<Metadata> {
        assert!(
            tranche_type == TRANCHE_SENIOR ||
            tranche_type == TRANCHE_MEZZ ||
            tranche_type == TRANCHE_JUNIOR,
            E_INVALID_TRANCHE_TYPE
        );

        let constructor_ref = &object::create_named_object(
            creator,
            generate_token_seed(pool_id, tranche_type)
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(), // max_supply
            name,
            symbol,
            8, // decimals
            string::utf8(b"https://stratafi.io/logo.png"), // icon
            string::utf8(b"https://stratafi.io"), 
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);

        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(&metadata_object_signer, Pool_Token_Capabilities {
            mint_cap: mint_ref,
            burn_cap: burn_ref,
        });
        object::object_from_constructor_ref<Metadata>(constructor_ref)
    }

    fun generate_token_seed(pool_id: u64, tranche_type: u8): vector<u8> {
        let seed = b"pool_";
    
        // Convert pool_id to bytes
        let pool_bytes = std::bcs::to_bytes(&pool_id);    
        seed.append(pool_bytes);
        // Append tranche type
        seed.push_back(tranche_type);
    
        seed 
    }

    // mint pool tokens, mint to investors 
    public fun mint_pool_tokens(
        token_metadata: Object<Metadata>,
        recipeint: address, 
        amount: u64,
    ) acquires Pool_Token_Capabilities {
        // get the address of the token 
        let token_addr = object::object_address(&token_metadata);
        // borrow the capabilities
        let capabilities = borrow_global<Pool_Token_Capabilities>(token_addr);

        let recipient_store = primary_fungible_store::ensure_primary_store_exists(
            recipeint,
            token_metadata,
        );

        let fa = fungible_asset::mint(&capabilities.mint_cap, amount);
        fungible_asset::deposit(recipient_store, fa);
    }

    // burn function-  the burn function will be called when investors redeem their pool tokens
    public fun burn_pool_tokens(
        owner_sign: &signer,
        token_metadata: Object<Metadata>,
        holder: address,
        amount: u64,
    ) acquires Pool_Token_Capabilities {
        // get the address of the token
        let token_addr = object::object_address(&token_metadata);
        // ge tthe capability of the token to burn 
        let capabilities = borrow_global<Pool_Token_Capabilities>(token_addr);
        // get the holder's store
        let holder_store = primary_fungible_store::primary_store(
            holder,
            token_metadata
        );

        let fa = fungible_asset::withdraw(
            owner_sign,
            holder_store,
            amount
        );

        fungible_asset::burn(&capabilities.burn_cap, fa);
    }
    

    // =========================
    // VIEW FUNCTIONS
    // =========================

    #[view]
    /// Get token balance of an address
    public fun balance_of(
        owner: address,
        token_metadata: Object<Metadata>
    ): u64 {
        primary_fungible_store::balance(owner, token_metadata)
    }

    #[view]
    /// Get total supply of a token
    /// Returns total number of tokens in circulation
    public fun total_supply(token_metadata: Object<Metadata>): u128 {
        let supply_option = fungible_asset::supply(token_metadata);
        if (supply_option.is_some()) {
            supply_option.extract()
        } else {
            0
        }
    }

    #[view]
    /// Get token name
    public fun name(token_metadata: Object<Metadata>): String {
        fungible_asset::name(token_metadata)
    }

    #[view]
    /// Get token symbol
    public fun symbol(token_metadata: Object<Metadata>): String {
        fungible_asset::symbol(token_metadata)
    }

    #[view]
    /// Get token decimals
    public fun decimals(token_metadata: Object<Metadata>): u8 {
        fungible_asset::decimals(token_metadata)
    }
}