require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s
  
  config.openapi_specs = {
    'v1/swagger.json' => {
      openapi: '3.0.0',
      info: {
        title: 'Clareo API',
        version: 'v1',
        description: 'Clareo BaaS - Banking as a Service API',
        contact: {
          name: 'Clareo Support',
          email: 'support@clareo.io'
        }
      },
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://api.clareo.io',
          description: 'Production server'
        }
      ],
      paths: {},
      components: {
        schemas: {
          Error: {
            type: 'object',
            properties: {
              error: { type: 'string' },
              status: { type: 'integer' }
            }
          },
          Organization: {
            type: 'object',
            properties: {
              id: { type: 'string', format: 'uuid' },
              name: { type: 'string' },
              external_id: { type: 'string', nullable: true },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['id', 'name']
          },
          Contributor: {
            type: 'object',
            properties: {
              id: { type: 'string', format: 'uuid' },
              organization_id: { type: 'string', format: 'uuid' },
              email: { type: 'string', format: 'email' },
              name: { type: 'string' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['id', 'organization_id', 'email']
          },
          Membership: {
            type: 'object',
            properties: {
              id: { type: 'string', format: 'uuid' },
              organization_id: { type: 'string', format: 'uuid' },
              contributor_id: { type: 'string', format: 'uuid' },
              role: { type: 'string', enum: ['admin', 'user'] },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['id', 'organization_id', 'contributor_id', 'role']
          },
          Wallet: {
            type: 'object',
            properties: {
              owner_type: { type: 'string', enum: ['organization', 'contributor'] },
              owner_id: { type: 'string', format: 'uuid' },
              balance_cents: { type: 'integer' },
              available_cents: { type: 'integer' },
              locked_cents: { type: 'integer' },
              version: { type: 'integer' },
              created_at: { type: 'string', format: 'date-time' },
              updated_at: { type: 'string', format: 'date-time' }
            },
            required: ['owner_type', 'owner_id', 'balance_cents']
          },
          Transaction: {
            type: 'object',
            properties: {
              transaction_id: { type: 'string', format: 'uuid' },
              owner_type: { type: 'string', enum: ['organization', 'contributor'] },
              owner_id: { type: 'string', format: 'uuid' },
              amount_cents: { type: 'integer' },
              currency: { type: 'string', default: 'BRL' },
              transaction_type: { type: 'string', enum: ['credit', 'debit', 'transfer', 'external_in', 'external_out', 'withdrawal'] },
              status: { type: 'string', enum: ['authorized', 'captured', 'refunded', 'failed', 'reversed'] },
              campaign_id: { type: 'string', format: 'uuid', nullable: true },
              idempotency_key: { type: 'string' },
              external_reference: { type: 'string', nullable: true },
              metadata: { type: 'object', nullable: true },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['transaction_id', 'owner_type', 'owner_id', 'amount_cents', 'transaction_type', 'status']
          },
          TransactionResponse: {
            allOf: [
              { '$ref': '#/components/schemas/Transaction' },
              {
                type: 'object',
                properties: {
                  transfer_id: { type: 'string', format: 'uuid', nullable: true },
                  provider_reference: { type: 'string', nullable: true }
                }
              }
            ]
          },
          PaymentMethod: {
            type: 'object',
            properties: {
              payment_method_id: { type: 'string', format: 'uuid' },
              owner_type: { type: 'string', enum: ['organization', 'contributor'] },
              owner_id: { type: 'string', format: 'uuid' },
              payment_type: { type: 'string', enum: ['credit_card', 'bank_transfer', 'pix'] },
              reference: { type: 'string' },
              is_default: { type: 'boolean' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['payment_method_id', 'owner_type', 'owner_id', 'payment_type']
          },
          CreditLine: {
            type: 'object',
            properties: {
              credit_line_id: { type: 'string', format: 'uuid' },
              owner_type: { type: 'string', enum: ['organization', 'contributor'] },
              owner_id: { type: 'string', format: 'uuid' },
              limit_cents: { type: 'integer' },
              available_cents: { type: 'integer' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['credit_line_id', 'owner_type', 'owner_id', 'limit_cents']
          }
        },
        securitySchemes: {
          ApiKeyAuth: {
            type: 'apiKey',
            in: 'header',
            name: 'X-API-Key'
          },
          BearerAuth: {
            type: 'http',
            scheme: 'bearer'
          }
        }
      }
    }
  }

  config.openapi_format = :json
end
