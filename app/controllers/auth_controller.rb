require "bcrypt"

class AuthController < ApplicationController
  skip_before_action :authenticate!, only: [:register, :login]

  def register
    email = params[:email]
    password = params[:password]
    name = params[:name]

    return render json: { error: "Email required" }, status: :unprocessable_entity unless email
    return render json: { error: "Password required" }, status: :unprocessable_entity unless password
    return render json: { error: "Name required" }, status: :unprocessable_entity unless name
    return render json: { error: "Password must be at least 8 characters" }, status: :unprocessable_entity if password.length < 8

    existing = UsersRepository.find_by_email(email)
    return render json: { error: "Email already registered" }, status: :conflict if existing

    password_hash = BCrypt::Password.create(password)
    user_id = UsersRepository.create(email: email, password_hash: password_hash, name: name)
    user = UsersRepository.find(user_id)

    wallet = CreateWalletService.call(owner_type: "user", owner_id: user_id)

    token = JwtAuth.encode({ user_id: user[:user_id].to_s, email: user[:email] })

    render json: {
      user: {
        user_id: user[:user_id].to_s,
        email: user[:email],
        name: user[:name]
      },
      wallet: wallet,
      token: token
    }, status: :created
  end

  def login
    email = params[:email]
    password = params[:password]

    return render json: { error: "Email required" }, status: :unprocessable_entity unless email
    return render json: { error: "Password required" }, status: :unprocessable_entity unless password

    user = UsersRepository.find_by_email(email)
    return render json: { error: "Invalid email or password" }, status: :unauthorized unless user

    bcrypt = BCrypt::Password.new(user[:password_hash])
    return render json: { error: "Invalid email or password" }, status: :unauthorized unless bcrypt == password

    token = JwtAuth.encode({ user_id: user[:user_id].to_s, email: user[:email] })

    render json: {
      user: {
        user_id: user[:user_id].to_s,
        email: user[:email],
        name: user[:name]
      },
      token: token
    }
  end

  def me
    render json: {
      user: {
        user_id: @current_user[:user_id].to_s,
        email: @current_user[:email],
        name: @current_user[:name]
      }
    }
  end
end
