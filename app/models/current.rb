# Who the current request belongs to. The session is set for browsers; API
# calls made with an api_key only have the user.
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user
end
