
// ============================================
// StrataFi Library Module
// Pure math functions for bonding curve calculations
// Similar to similar uniswap Library
// ===========================================

module stratafi::math {

// all error code follow a binary schema
// math Errors 1 - 100
/// @error E_MATH_DIVIDE_BY_ZERO: Divide by zero error
const E_MATH_DIVIDE_BY_ZERO: u64 = 1;
/// @error E_MATH_ZERO_VALUE: Zero value error
const E_MATH_ZERO_VALUE: u64 = 10;
/// @error E_amount_ZERO: Amount is zero error
const E_amount_ZERO: u64 = 11;
/// @error E_reserve_ZERO: Reserve is zero error
const E_reserve_ZERO: u64 = 100;
/// @error E_INSUFFICIENT_LIQUIDITY: Insufficient liquidity error
const E_INSUFFICIENT_LIQUIDITY: u64 = 101;

struct Fraction has copy, drop, store {
    num: u64,
    dem: u64,
}

// ============================================
// MATH FUNCTIONS 
// ===========================================
    /// GET THE AMOUNT OF POOL TOKEN OUT FOR A GIVEN UDSC
    /// this will be used by the bounding curve to determine ffg X * Y = K
    /**
    @param amount_in: u64 - the amount of input token (e.g., USDC)
    @param reserve_in: u64 - the reserve of input token in the pool
    @param reserve_out: u64 - the reserve of output token in the pool
    */
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
        fee: Fraction
    ): u64 {
        assert!(amount_in > 0, E_amount_ZERO);
        assert!(reserve_in > 0, E_reserve_ZERO);
        assert!(reserve_out > 0, E_reserve_ZERO);

        let amount_in_after_fee = apply_Fee(amount_in, fee);
        // following the x * y = k formula
        // amount_out = (amount_in * reserve_out) / (reserve_in + amount_in)
        let numerator = mul_as_u128(amount_in_after_fee, reserve_out);
        let denominator = (reserve_in as u128) + (amount_in_after_fee as u128);

        let amount_out = numerator / denominator;
        amount_out as u64   
    }

    public fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
        fee: Fraction
    ): u64 {
        assert!(amount_out > 0, E_amount_ZERO);
        assert!(reserve_in > 0, E_reserve_ZERO);
        assert!(reserve_out > 0, E_reserve_ZERO);
        assert!(reserve_out > amount_out, E_INSUFFICIENT_LIQUIDITY);

        // following the x * y = k formula
        // amount_in = (reserve_in * amount_out * fee_dom) / (reserve_out - amount_out * fee_num)
        let numerator = mul_u128(mul_as_u128(reserve_in, amount_out) , fee.dem as u128);

        let denominator = mul_as_u128((reserve_out - amount_out) , fee.num);

        let amount_in = numerator / denominator;
        amount_in as u64
    }

// ============================================
// HELPER FUNCTIONS 
// ===========================================

    /// Apply fee to amount
    /**
    @param amount: u64 - the amount to apply fee on
    @param fee: Fraction - the fee as a fraction (num/den)
    @return u64 - amount after fee is applied
    */
    public fun apply_Fee(amount: u64, fee: Fraction): u64 {
        let fee_amount = div_mul(amount, fee.num, fee.dem);
        amount - fee_amount
    }

    /// Safely multiply and divide: (x * y) / z
    /// Prevents overflow by using u128
    /**
    @param x: u64 - first multiplic
    @param y: u64 - second multiplic
    @param z: u64 - divisor
    @return u64 - result of (x * y) / z
    */
    public fun div_mul(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, E_MATH_DIVIDE_BY_ZERO);        
        let result = ((x as u128) * (y as u128)) / (z as u128);
        result as u64
    }
    // mul two u64 numbers and return u128
    public fun mul_as_u128(x: u64,y: u64): u128 {
        (x as u128) * (y as u128)
    }

    // mul two u128 numbers
    public fun mul_u128(x: u128, y: u128): u128 {
        x * y
    }
}
