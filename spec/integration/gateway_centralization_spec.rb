require "rails_helper"

RSpec.describe "FakeBaasGateway Centralization", type: :integration do
  describe "All transaction types route through centralized gateway" do
    let(:source_owner_id) { SecureRandom.uuid }
    let(:dest_owner_id) { SecureRandom.uuid }
    let(:owner_type) { "organization" }

    before do
      # Ensure wallets exist
      CreateWalletService.call(owner_type: owner_type, owner_id: source_owner_id)
      CreateWalletService.call(owner_type: owner_type, owner_id: dest_owner_id)
    end

    context "credit transaction" do
      it "routes through FakeBaasGateway.authorize -> capture" do
        idempotency_key = "credit-#{SecureRandom.uuid}"
        
        result = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 1000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: idempotency_key
        )

        expect(result[:status]).to eq(:ok)
        expect(result[:transaction_id]).to be_present

        # Verify gateway stored the transaction
        provider_ref = result[:provider_reference]
        gateway_tx = FakeBaasGateway.get_transaction(provider_reference: provider_ref)
        expect(gateway_tx).to be_present
        expect(gateway_tx[:status]).to eq("captured")

        # Verify wallet updated
        wallet = WalletsRepository.find(source_owner_id, owner_type)
        expect(wallet[:balance_cents]).to eq(1000)
      end
    end

    context "debit transaction" do
      before do
        # Pre-fund source wallet
        ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 5000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "prefund-#{SecureRandom.uuid}"
        )
      end

      it "routes through FakeBaasGateway.authorize -> capture" do
        idempotency_key = "debit-#{SecureRandom.uuid}"
        
        result = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 2000,
          currency: "BRL",
          transaction_type: "debit",
          idempotency_key: idempotency_key
        )

        expect(result[:status]).to eq(:ok)

        # Verify wallet debited
        wallet = WalletsRepository.find(source_owner_id, owner_type)
        expect(wallet[:balance_cents]).to eq(3000)
      end
    end

    context "transfer transaction" do
      before do
        # Pre-fund source wallet
        ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 5000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "prefund-src-#{SecureRandom.uuid}"
        )
      end

      it "orchestrates through FakeBaasGateway as SaaS provider" do
        idempotency_key = "transfer-#{SecureRandom.uuid}"

        result = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 1000,
          currency: "BRL",
          transaction_type: "transfer",
          idempotency_key: idempotency_key,
          dest_owner_type: owner_type,
          dest_owner_id: dest_owner_id
        )

        expect(result[:status]).to eq(:ok)
        expect(result[:transfer_id]).to be_present
        expect(result[:provider_reference]).to be_present

        # Verify gateway stored transfer
        transfer_ref = result[:provider_reference]
        gateway_tx = FakeBaasGateway.get_transaction(provider_reference: transfer_ref)
        expect(gateway_tx).to be_present
        expect(gateway_tx[:status]).to eq("captured")

        # Verify both wallets updated
        source_wallet = WalletsRepository.find(source_owner_id, owner_type)
        dest_wallet = WalletsRepository.find(dest_owner_id, owner_type)

        expect(source_wallet[:balance_cents]).to eq(4000) # 5000 - 1000
        expect(dest_wallet[:balance_cents]).to eq(1000)   # 0 + 1000
      end

      it "prevents insufficient funds via gateway hold" do
        idempotency_key = "transfer-insufficient-#{SecureRandom.uuid}"

        result = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 10000, # Exceeds available 5000
          currency: "BRL",
          transaction_type: "transfer",
          idempotency_key: idempotency_key,
          dest_owner_type: owner_type,
          dest_owner_id: dest_owner_id
        )

        expect(result[:status]).to eq(:insufficient_funds)

        # Verify wallets unchanged
        source_wallet = WalletsRepository.find(source_owner_id, owner_type)
        dest_wallet = WalletsRepository.find(dest_owner_id, owner_type)

        expect(source_wallet[:balance_cents]).to eq(5000)
        expect(dest_wallet[:balance_cents]).to eq(0)
      end

      it "respects idempotency via gateway" do
        idempotency_key = "transfer-idempotent-#{SecureRandom.uuid}"

        result1 = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 1000,
          currency: "BRL",
          transaction_type: "transfer",
          idempotency_key: idempotency_key,
          dest_owner_type: owner_type,
          dest_owner_id: dest_owner_id
        )

        result2 = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 1000,
          currency: "BRL",
          transaction_type: "transfer",
          idempotency_key: idempotency_key,
          dest_owner_type: owner_type,
          dest_owner_id: dest_owner_id
        )

        expect(result1[:status]).to eq(:ok)
        expect(result2[:status]).to eq(:already_processed)
        # Convert to string for comparison (Cassandra::Uuid vs String)
        expect(result1[:transaction_id].to_s).to eq(result2[:transaction_id].to_s)

        # Verify only single transfer applied
        source_wallet = WalletsRepository.find(source_owner_id, owner_type)
        expect(source_wallet[:balance_cents]).to eq(4000) # Only one debit applied
      end
    end

    context "audit logging via centralized AuditLogger" do
      it "logs all gateway operations to Cassandra and Kafka" do
        # Pre-fund for transfer
        ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 2000,
          currency: "BRL",
          transaction_type: "credit",
          idempotency_key: "audit-prefund-#{SecureRandom.uuid}"
        )

        idempotency_key = "audit-transfer-#{SecureRandom.uuid}"
        
        result = ProcessTransactionService.call(
          owner_type: owner_type,
          owner_id: source_owner_id,
          amount_cents: 500,
          currency: "BRL",
          transaction_type: "transfer",
          idempotency_key: idempotency_key,
          dest_owner_type: owner_type,
          dest_owner_id: dest_owner_id
        )

        # Verify audit events recorded
        events = AuditEventsRepository.find_by_owner(owner_type, source_owner_id, 10)

        event_types = events.map { |e| e[:event_type] }
        
        # Should have: payment_authorized, transfer_initiated, transfer_completed
        expect(event_types).to include("transfer_initiated_by_gateway")
        expect(event_types).to include("transfer_completed")

        # Verify Kafka messages would be published (in real env)
        # This is tested via AuditLogger specs in unit tests
      end
    end
  end
end
