# Someone asked for a sign-in link. Addresses on the guest list get a one-time
# token by email. The others are recorded too, so the admin page shows who
# tried to get in. Only the token's digest is stored.
class SignInRequest
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  LIFETIME = 15.minutes
  LINKS_PER_LIFETIME = 3

  field :email, type: String
  field :admitted, type: Boolean, default: false
  field :ip_address, type: String
  field :token_digest, type: String
  field :expires_at, type: Time
  field :redeemed_at, type: Time

  index({ token_digest: 1 }, { unique: true, sparse: true })
  index({ email: 1, created_at: -1 })
  index({ created_at: -1 })

  before_create :issue_token, if: :admitted

  attr_reader :token

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  # Records the request and, for a guest, issues the token to email. Returns
  # nil when the address already got its share of links for now.
  def self.open(email:, ip_address:)
    email = email.to_s.strip.downcase
    return if where(email:, admitted: true, :created_at.gte => LIFETIME.ago).count >= LINKS_PER_LIFETIME

    create!(email:, ip_address:, admitted: Guest.admits?(email))
  end

  # The request a token belongs to, while its link can still be used.
  def self.find_redeemable(token)
    return if token.blank?

    where(token_digest: digest(token), redeemed_at: nil, :expires_at.gt => Time.current).first
  end

  # Spends the link. When two clicks race, only one of them gets true.
  def redeem!
    self.class.where(_id: id, redeemed_at: nil).find_one_and_update("$set" => { redeemed_at: Time.current }).present?
  end

  def status
    if !admitted then "refused"
    elsif redeemed_at then "used"
    elsif expires_at.past? then "expired"
    else "sent"
    end
  end

  private

  def issue_token
    @token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@token)
    self.expires_at = LIFETIME.from_now
  end
end
