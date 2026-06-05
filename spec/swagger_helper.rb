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
          },
          Campaign: {
            type: 'object',
            properties: {
              campaign_id: { type: 'string', format: 'uuid' },
              organization_id: { type: 'string', format: 'uuid' },
              name: { type: 'string' },
              goal_cents: { type: 'integer' },
              raised_cents: { type: 'integer' },
              status: { type: 'string' },
              created_at: { type: 'string', format: 'date-time' }
            }
          },
          ExpenseEntry: {
            type: 'object',
            properties: {
              entry_id: { type: 'string', format: 'uuid' },
              organization_id: { type: 'string', format: 'uuid' },
              campaign_id: { type: 'string', format: 'uuid' },
              description: { type: 'string' },
              amount_cents: { type: 'integer' },
              category: { type: 'string' },
              expense_date: { type: 'string', format: 'date' },
              status: { type: 'string' },
              created_at: { type: 'string', format: 'date-time' }
            }
          },
          ExpenseAttachment: {
            type: 'object',
            properties: {
              attachment_id: { type: 'string', format: 'uuid' },
              filename: { type: 'string' },
              original_filename: { type: 'string' },
              content_type: { type: 'string' },
              file_size: { type: 'integer' },
              created_at: { type: 'string', format: 'date-time' }
            }
          },
          RecurringDonation: {
            type: 'object',
            properties: {
              recurring_id: { type: 'string', format: 'uuid' },
              organization_id: { type: 'string', format: 'uuid' },
              contributor_id: { type: 'string', format: 'uuid' },
              amount_cents: { type: 'integer' },
              interval_days: { type: 'integer' },
              payment_method: { type: 'string' },
              status: { type: 'string' },
              next_charge_date: { type: 'string', format: 'date' },
              created_at: { type: 'string', format: 'date-time' }
            }
          },
          Dashboard: {
            type: 'object',
            properties: {
              organization_id: { type: 'string', format: 'uuid' },
              name: { type: 'string' },
              metrics: {
                type: 'object',
                properties: {
                  total_raised_cents: { type: 'integer' },
                  total_spent_cents: { type: 'integer' },
                  balance_cents: { type: 'integer' },
                  wallet_available_cents: { type: 'integer' },
                  active_campaigns: { type: 'integer' },
                  total_campaigns: { type: 'integer' },
                  member_count: { type: 'integer' },
                  credit_line_available_cents: { type: 'integer' }
                }
              },
              campaigns: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    campaign_id: { type: 'string', format: 'uuid' },
                    name: { type: 'string' },
                    status: { type: 'string' },
                    raised_cents: { type: 'integer' },
                    spent_cents: { type: 'integer' },
                    balance_cents: { type: 'integer' },
                    goal_cents: { type: 'integer' },
                    progress_pct: { type: 'number', format: 'float' }
                  }
                }
              },
              recent_transactions: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    transaction_id: { type: 'string', format: 'uuid' },
                    amount_cents: { type: 'integer' },
                    transaction_type: { type: 'string' },
                    status: { type: 'string' },
                    campaign_id: { type: 'string', format: 'uuid', nullable: true },
                    created_at: { type: 'string', format: 'date-time' }
                  }
                }
              }
            }
          },
          AccountabilityReport: {
            type: 'object',
            properties: {
              organization: {
                type: 'object',
                properties: {
                  id: { type: 'string', format: 'uuid' },
                  name: { type: 'string' }
                }
              },
              campaign: { '$ref': '#/components/schemas/Campaign' },
              summary: {
                type: 'object',
                properties: {
                  total_raised: { type: 'integer' },
                  total_spent: { type: 'integer' },
                  balance: { type: 'integer' },
                  expense_count: { type: 'integer' }
                }
              },
              expenses: {
                type: 'array',
                items: {
                  allOf: [
                    { '$ref': '#/components/schemas/ExpenseEntry' },
                    {
                      type: 'object',
                      properties: {
                        attachments: {
                          type: 'array',
                          items: { '$ref': '#/components/schemas/ExpenseAttachment' }
                        }
                      }
                    }
                  ]
                }
              }
            }
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
