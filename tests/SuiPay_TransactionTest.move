#[test_only]
module suipay::SuiPay_TransactionTestSuite {
    use suipay::SuiPay_TransactionModel::{
        Self, 
        PaymentRequest, 
        PaymentRequestTable,
        new_payment_request_table,
        new_payment_request,
        is_fulfilled,
        get_requests,
        get_id,
        create_request,
        create_request_for_test,
        fulfill_request,
        destroy_payment_request,
        destroy_payment_request_table
    };
    use sui::object::{Self};
    use sui::tx_context::{Self};
    use sui::coin::{Self};
    use sui::clock::{Self};
    use sui::sui::SUI;
    use sui::table;

    // Make sure this matches the constant in your main module
    const ERR_EXPIRED: u64 = 0;

    #[test]
    public fun test_create_request() {
        let mut ctx = tx_context::dummy();
        let mut payment_table = new_payment_request_table(&mut ctx);
        let receiver = @0x123;
        let amount = 1000;
        let expiry_time = 2000;
        
        // Use the create_request_for_test function that returns the key
        let key = create_request_for_test(receiver, amount, expiry_time, &mut payment_table, &mut ctx);
        
        // Now check if the table contains the request with the correct key
        assert!(table::contains(get_requests(&payment_table), key), 0);
        
        // Clean up
        destroy_payment_request_table(payment_table);
    }

    #[test]
    public fun test_fulfill_request() {
        let mut ctx = tx_context::dummy();
        let sender = tx_context::sender(&ctx);
        let receiver = @0x123;
        let mut request = new_payment_request(sender, receiver, 1000, 2000, &mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::increment_for_testing(&mut clock, 1500);
        let coin = coin::mint_for_testing<SUI>(1000, &mut ctx);
        
        fulfill_request(&mut request, coin, &clock);
        assert!(is_fulfilled(&request), 0);
        
        // Clean up
        clock::destroy_for_testing(clock);
        destroy_payment_request(request);
    }

    #[test]
    #[expected_failure(abort_code = ERR_EXPIRED, location = suipay::SuiPay_TransactionModel)]
    public fun test_fulfill_expired_request_fails() {
        let mut ctx = tx_context::dummy();
        let sender = tx_context::sender(&ctx);
        let receiver = @0x123;
        let mut request = new_payment_request(sender, receiver, 1000, 1000, &mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::increment_for_testing(&mut clock, 1500);
        let coin = coin::mint_for_testing<SUI>(1000, &mut ctx);
        
        fulfill_request(&mut request, coin, &clock); // Should fail
        
        // Clean up (this won't execute due to the expected failure)
        clock::destroy_for_testing(clock);
        destroy_payment_request(request);
    }
}
