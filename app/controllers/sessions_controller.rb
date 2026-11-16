class SessionsController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 10, within: 10.minutes, only: :create, by: -> { client_ip },
    with: -> { redirect_to sign_in_path, alert: "Too many sign-in attempts. Try again in a few minutes." }

  # GET /sign_in
  def new
    redirect_to playground_path if authenticated?
  end

  # POST /sign_in. Answers the same whether or not the address is on the guest
  # list, so the page doesn't reveal who is.
  def create
    email = params[:email].to_s.strip.downcase
    return redirect_to sign_in_path, alert: "Enter your email address." unless email.match?(Guest::EMAIL)

    sign_in_request = SignInRequest.open(email:, ip_address: client_ip)
    if sign_in_request&.token
      SignInMailer.link(sign_in_request).deliver_now
      flash[:dev_link] = sign_in_link_url(token: sign_in_request.token) if Rails.env.development?
    end
    redirect_to sign_in_sent_path, flash: { email: }
  end

  # GET /sign_in/sent
  def sent
  end

  # DELETE /sign_out
  def destroy
    resume_session
    terminate_session
    redirect_to root_path
  end
end
