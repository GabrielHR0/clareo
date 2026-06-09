require "swagger_helper"

RSpec.describe "Auth", type: :request do
  path "/api/v1/auth/register" do
    post "Register a new user" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :body, in: :body, schema: {
        type: "object",
        properties: {
          email: { type: "string", format: "email" },
          password: { type: "string", minLength: 8 },
          name: { type: "string" }
        },
        required: %w[email password name]
      }, description: "User registration payload"

      response "201", "User registered" do
        example :json, :register_201, {
          user: {
            user_id: "4c118bfb-f04a-494e-b767-7da34ac483fa",
            email: "novo@email.com",
            name: "Novo"
          },
          token: "eyJhbGciOiJIUzI1NiJ9..."
        }
      end

      response "409", "Email already registered" do
        example :json, :register_409, {
          error: "Email already registered"
        }
      end

      response "422", "Invalid parameters" do
        example :json, :register_422, {
          error: "Password must be at least 8 characters"
        }
      end
    end
  end

  path "/api/v1/auth/login" do
    post "Log in" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :body, in: :body, schema: {
        type: "object",
        properties: {
          email: { type: "string", format: "email" },
          password: { type: "string" }
        },
        required: %w[email password]
      }, description: "Login payload"

      response "200", "Login successful" do
        example :json, :login_200, {
          user: {
            user_id: "4c118bfb-f04a-494e-b767-7da34ac483fa",
            email: "teste@email.com",
            name: "Teste"
          },
          token: "eyJhbGciOiJIUzI1NiJ9..."
        }
      end

      response "401", "Invalid credentials" do
        example :json, :login_401, {
          error: "Invalid email or password"
        }
      end
    end
  end

  path "/api/v1/auth/me" do
    get "Get current user" do
      tags "Auth"
      produces "application/json"
      security [{ BearerAuth: [] }]

      response "200", "Current user data" do
        security [{ BearerAuth: [] }]
        example :json, :me_200, {
          user: {
            user_id: "4c118bfb-f04a-494e-b767-7da34ac483fa",
            email: "teste@email.com",
            name: "Teste",
            contributor_id: "d0ac27ef-577a-49ff-83cc-8b8dd2c9973c"
          }
        }
      end

      response "401", "Unauthorized" do
        security [{ BearerAuth: [] }]
        example :json, :me_401, {
          error: "Invalid or expired token"
        }
      end
    end
  end

  path "/api/v1/auth/me/contributor" do
    get "Get my contributor profile" do
      tags "Auth"
      produces "application/json"
      security [{ BearerAuth: [] }]

      response "200", "Contributor data" do
        security [{ BearerAuth: [] }]
        example :json, :me_contributor_200, {
          contributor_id: "d0ac27ef-577a-49ff-83cc-8b8dd2c9973c",
          name: "Teste",
          email: "teste@email.com",
          cpf: nil,
          phone: nil,
          status: "active",
          created_at: "2026-06-08T10:10:24.945-03:00",
          updated_at: "2026-06-08T10:10:24.945-03:00"
        }
      end

      response "404", "User has no contributor" do
        security [{ BearerAuth: [] }]
        example :json, :me_contributor_404, {
          error: "Not found"
        }
      end
    end
  end
end
