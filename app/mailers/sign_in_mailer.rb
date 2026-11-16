class SignInMailer < ApplicationMailer
  def link(sign_in_request)
    @url = sign_in_link_url(token: sign_in_request.token)
    @minutes = SignInRequest::LIFETIME.in_minutes.to_i
    mail to: sign_in_request.email, subject: "Your sign-in link for the Reclame Aqui API demo"
  end
end
