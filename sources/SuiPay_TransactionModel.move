module suipay::SuiPay_TransactionModel {
    use sui::object::{UID};
    use sui::tx_context::{TxContext};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::address;
    use sui::bcs;
    use sui::table;

    const ERR_EXPIRED: u64 = 0;
    const ERR_ALREADY_FULFILLED: u64 = 1;
    const ERR_AMOUNT_MISMATCH: u64 = 2;

    public struct PaymentRequest has key, store {
        id: UID,
        sender: address,
        receiver: address,
        amount: u64,
        expiry_time: u64,
        fulfilled: bool
    }

    public struct PaymentRequestTable has key, store {
        id: UID,
        requests: table::Table<vector<u8>, PaymentRequest>,
    }

    public fun new_payment_request_table(ctx: &mut TxContext): PaymentRequestTable {
        PaymentRequestTable {
            id: object::new(ctx),
            requests: table::new(ctx),
        }
    }

    #[test_only]
    public fun new_payment_request(
        sender: address,
        receiver: address,
        amount: u64,
        expiry_time: u64,
        ctx: &mut TxContext
    ): PaymentRequest {
        PaymentRequest {
            id: object::new(ctx),
            sender,
            receiver,
            amount,
            expiry_time,
            fulfilled: false
        }
    }

    #[test_only]
    public fun destroy_payment_request(request: PaymentRequest) {
        let PaymentRequest { id, sender: _, receiver: _, amount: _, expiry_time: _, fulfilled: _ } = request;
        object::delete(id);
    }

    #[test_only]
    public fun destroy_payment_request_table(table: PaymentRequestTable) {
        let PaymentRequestTable { id, requests } = table;
        table::destroy_empty(requests); // Assumes table is empty; adjust if needed
        object::delete(id);
    }

    public fun is_fulfilled(request: &PaymentRequest): bool {
        request.fulfilled
    }

    public fun get_requests(table: &PaymentRequestTable): &table::Table<vector<u8>, PaymentRequest> {
        &table.requests
    }

    public fun get_id(request: &PaymentRequest): &UID {
        &request.id
    }

    public entry fun create_request(
        receiver: address,
        amount: u64,
        expiry_time: u64,
        payment_request_table: &mut PaymentRequestTable,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);

        let payment_request = PaymentRequest {
            id,
            sender,
            receiver,
            amount,
            expiry_time,
            fulfilled: false
        };

        let key = object::uid_to_bytes(&payment_request.id);
        table::add(&mut payment_request_table.requests, key, payment_request);
    }

    #[test_only]
    public fun create_request_for_test(
        receiver: address,
        amount: u64,
        expiry_time: u64,
        payment_request_table: &mut PaymentRequestTable,
        ctx: &mut TxContext
    ): vector<u8> {
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);

        let payment_request = PaymentRequest {
            id,
            sender,
            receiver,
            amount,
            expiry_time,
            fulfilled: false
        };

        let key = object::uid_to_bytes(&payment_request.id);
        table::add(&mut payment_request_table.requests, key, payment_request);
        key
    }

    public entry fun fulfill_request(
        request: &mut PaymentRequest,
        coin: Coin<SUI>,
        clock: &Clock,
    ) {
        let now = clock.timestamp_ms();
        assert!(now <= request.expiry_time, ERR_EXPIRED);
        assert!(!request.fulfilled, ERR_ALREADY_FULFILLED);
        assert!(coin::value(&coin) == request.amount, ERR_AMOUNT_MISMATCH);

        request.fulfilled = true;
        transfer::public_transfer(coin, request.receiver);
    }

    public fun generate_invoice(request: &PaymentRequest): vector<u8> {
        let mut invoice = vector::empty<u8>();
        vector::append(&mut invoice, address::to_bytes(request.sender));
        vector::append(&mut invoice, address::to_bytes(request.receiver));
        vector::append(&mut invoice, u64_to_bytes(request.amount));
        vector::append(&mut invoice, u64_to_bytes(request.expiry_time));
        invoice
    }

    fun u64_to_bytes(value: u64): vector<u8> {
        bcs::to_bytes(&value)
    }
}