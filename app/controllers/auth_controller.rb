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

    contributor_result = CreateContributorService.call(name: name, email: email)
    contributor = contributor_result[:contributor]

    UsersRepository.update(user_id, contributor_id: contributor[:contributor_id])

    exp = 24.hours.from_now
    token = JwtAuth.encode({ user_id: user[:user_id].to_s, email: user[:email] }, exp)

    # Whitelist the token in Redis for distributed auth
    jti = JwtAuth.extract_jti(token)
    TokenBlacklist.whitelist!(jti, exp.to_i) if jti

    # Publish event for cross-instance notification
    EventBus.publish("user.registered", {
      user_id: user[:user_id].to_s,
      email: user[:email],
      name: user[:name]
    })

    render json: {
      user: {
        user_id: user[:user_id].to_s,
        email: user[:email],
        name: user[:name],
        contributor_id: contributor[:contributor_id].to_s
      },
      wallet: wallet,
      contributor: contributor,
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

    exp = 24.hours.from_now
    token = JwtAuth.encode({ user_id: user[:user_id].to_s, email: user[:email] }, exp)

    # Whitelist the token in Redis for distributed auth
    jti = JwtAuth.extract_jti(token)
    TokenBlacklist.whitelist!(jti, exp.to_i) if jti

    render json: {
      user: {
        user_id: user[:user_id].to_s,
        email: user[:email],
        name: user[:name]
      },
      token: token
    }
  end

  # Logout: blacklist the current token so it can't be used on any instance.
  # POST /auth/logout
  def logout
    token = bearer_token
    if token
      jti = JwtAuth.extract_jti(token)
      if jti
        payload = JwtAuth.decode(token)
        exp = payload ? payload["exp"] : 24.hours.from_now.to_i
        TokenBlacklist.blacklist!(jti, exp)
      end
    end

    head :ok
  end

  def me
    user = UsersRepository.find(@current_user[:user_id])

    render json: {
      user: {
        user_id: user[:user_id].to_s,
        email: user[:email],
        name: user[:name],
        contributor_id: user[:contributor_id]&.to_s
      }
    }
  end

  def me_contributor
    user = UsersRepository.find(@current_user[:user_id])
    return head :not_found unless user[:contributor_id]

    contributor = ContributorsRepository.find(user[:contributor_id])
    return head :not_found unless contributor

    render json: contributor
  end
end
