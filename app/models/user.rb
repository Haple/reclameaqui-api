# Someone who signed in at least once. Whether they still may is up to the
# guest list, checked on every request, so removing a guest locks them out.
class User
  include Mongoid::Document
  include Mongoid::Timestamps

  # Seen-at updates are throttled so browsing doesn't write on every request.
  SEEN_PRECISION = 5.minutes

  field :email, type: String
  field :api_key, type: String, default: -> { SecureRandom.hex(32) }
  field :last_seen_at, type: Time

  has_many :sessions, dependent: :delete_all
  has_many :search_requests

  index({ email: 1 }, { unique: true })
  index({ api_key: 1 }, { unique: true })

  def guest?
    Guest.admits?(email)
  end

  def admin?
    Guest.admin?(email)
  end

  def seen!
    set(last_seen_at: Time.current) if last_seen_at.nil? || last_seen_at < SEEN_PRECISION.ago
  end
end
