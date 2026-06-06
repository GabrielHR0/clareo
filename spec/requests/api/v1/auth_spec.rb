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
        let(:body) { { email: "novo@email.com", password: "12345678", name: "Novo" } }
        example :json, :register_201, {
          user: {
            user_id: "4c118bfb-f04a-494e-b767-7da34ac483fa",
            email: "novo@email.com",
            name: "Novo"
          },
          token: "eyJhbGciOiJIUzI1NiJ9..."
        }
        run_test!
      end

      response "409", "Email already registered" do
        let(:body) { { email: "ja_existe@email.com", password: "12345678", name: "Existente" } }
        example :json, :register_409, {
          error: "Email already registered"
        }
        run_test!
      end

      response "422", "Invalid parameters" do
        let(:body) { { email: "invalido@email.com", password: "curta", name: "X" } }
        example :json, :register_422, {
          error: "Password must be at least 8 characters"
        }
        run_test!
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
        let(:body) { { email: "teste@email.com", password: "12345678" } }
        example :json, :login_200, {
          user: {
            user_id: "4c118bfb-f04a-494e-b767-7da34ac483fa",
            email: "teste@email.com",
            name: "Teste"
          },
          token: "eyJhbGciOiJIUzI1NiJ9..."
        }
        run_test!
      end

      response "401", "Invalid credentials" do
        let(:body) { { email: "errado@email.com", password: "senha_errada" } }
        example :json, :login_401, {
          error: "Invalid email or password"
        }
        run_test!
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
            name: "Teste"
          }
        }
        run_test!
      end

      response "401", "Unauthorized" do
        security [{ BearerAuth: [] }]
        example :json, :me_401, {
          error: "Invalid or expired token"
        }
        run_test!
      end
    end
  end
end
