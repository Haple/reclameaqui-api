# The link in the sign-in email. Opening it shows a button and only the POST
# spends the token, so mail scanners that prefetch links can't use it up.
class SignInLinksController < ApplicationController
  allow_unauthenticated_access

  before_action { @sign_in_request = SignInRequest.find_redeemable(params[:token]) }

  # GET /sign_in/link?token=...
  def show
    render status: :gone unless @sign_in_request
  end

  # POST /sign_in/link
  def create
    return render :show, status: :gone unless @sign_in_request&.redeem!

    start_new_session_for User.find_or_create_by!(email: @sign_in_request.email)
    redirect_to after_authentication_url
  end
end
