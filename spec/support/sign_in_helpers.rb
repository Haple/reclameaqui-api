module SignInHelpers
  # Signs in the way a guest does: asks for a link, reads it from the email
  # and presses the button on the page it opens.
  def sign_in(email = "ana@serpapi.com", admin: false)
    Guest.create!(pattern: email, admin:) unless Guest.admits?(email)
    post "/sign_in", params: { email: }
    post "/sign_in/link", params: { token: token_from(last_email) }
    User.find_by(email:)
  end

  def last_email
    ActionMailer::Base.deliveries.last
  end

  def token_from(mail)
    mail.text_part.body.to_s[/token=([\w-]+)/, 1]
  end
end
