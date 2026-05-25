require 'securerandom'

module PaymentGateway
  extend self

  # Stubbed card charge method. Replace with real provider integration.
  # Returns a hash with :success (boolean) and :reference (string) and optional :error
  def charge_card(card_reference:, amount_cents:, currency: "BRL")
    # In real implementation call external API (Stripe, Pagar.me, etc.)
    reference = "card_tx_#{SecureRandom.hex(8)}"
    { success: true, reference: reference }
  rescue => e
    { success: false, error: e.message }
  end
end
