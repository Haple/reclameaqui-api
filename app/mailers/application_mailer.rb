class ApplicationMailer < ActionMailer::Base
  default({ from: ENV.fetch("MAIL_FROM", "Reclame Aqui API <demo@example.com>"), reply_to: Rails.configuration.x.contact_email }.compact)
  layout "mailer"
end
