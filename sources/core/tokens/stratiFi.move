// ============================
// StratiFi Move Module
// =============================
module stratafi::STFI {
    // =========================
    // import 
    // =========================
    use aptos_framework::coin::{Self, MintCapability, BurnCapability, FreezeCapability}; 
    use std::signer;
    use std::string;

    // =========================
    // errors
    // =========================
    // all error code follow a binary schema 100 to 200
    const ERROR_INVALID_ARGUMENTS: u64 = 100;
    const E_MATH_ZERO_VALUE: u64 = 110;

    // =========================
    // struct
    // =========================
    struct STFI has key {
    }

    struct STFI_Capabilities has key  {
        mint_cap: MintCapability<STFI>,
        burn_cap: BurnCapability<STFI>,
        freeze_cap: FreezeCapability<STFI>,
    }

    fun init_module(stratFi_admin: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<STFI>(
            stratFi_admin,
            string::utf8(b"StratiFi Token"),
            string::utf8(b"STFI"),
            8,
            true,
        );

        // move the capabilities to a resource under the admin's account
        move_to(stratFi_admin, STFI_Capabilities {
            mint_cap,
            burn_cap,
            freeze_cap,
        });

        coin::register<STFI>(stratFi_admin);
        coin::destroy_freeze_cap<STFI>(freeze_cap);
    }

    public entry fun mint_stratiFi(
        stratFi_admin: &signer,
        recipient: address,
        amount: u64,
    ) acquires STFI_Capabilities {
         // step 7.1:: get capabilities 
        let admin_addr = signer::address_of(stratFi_admin);
        let capabilities = borrow_global<STFI_Capabilities>(admin_addr);

        let coins = coin::mint<STFI>(amount, &capabilities.mint_cap);
        coin::deposit<STFI>(recipient, coins);
    }

    public entry fun burn_stratiFi(
        strataFi_admin: &signer,
        amount: u64,
    ) acquires STFI_Capabilities {
         // step 8.1:: get capabilities 
        let admin_addr = signer::address_of(strataFi_admin);
        let capabilities = borrow_global<STFI_Capabilities>(admin_addr);

        let coins = coin::withdraw<STFI>(strataFi_admin, amount);
        coin::burn<STFI>(coins, &capabilities.burn_cap);
    }

    // ============================================
    // STEP 10: VIEW FUNCTIONS
    // ============================================
    
    #[view]
    /// Get balance of an address
    public fun balance_of(addr: address): u64 {
        coin::balance<STFI>(addr)
    }
    
    #[view]
    /// Get token name
    public fun name(): string::String {
        coin::name<STFI>()
    }
    
    #[view]
    /// Get token symbol
    public fun symbol(): string::String {
        coin::symbol<STFI>()
    }
    

}


