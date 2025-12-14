module stratafi::errors {
    // all error code follow a binary schema
    // math Errors 1 - 100
    const E_MATH_DIVIDE_BY_ZERO: u64 = 1;
    const E_MATH_ZERO_VALUE: u64 = 10;

    public fun throw_math_divide_by_zero_error() {
        abort E_MATH_DIVIDE_BY_ZERO;
    }

    public fun throw_math_zero_value_error() {
        abort E_MATH_ZERO_VALUE;
    }
    // pool error 100 - 200
}