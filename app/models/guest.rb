# The allow list for the playground and the live API. An entry is an address
# ("ana@example.com") or a whole domain ("@example.com"). Managed with
# bin/rails guests:add, guests:remove and guests:list.
class Guest
  include Mongoid::Document
  include Mongoid::Timestamps

  PATTERN = /\A[^@\s]*@[^@\s]+\.[^@\s]+\z/
  EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  field :pattern, type: String
  field :admin, type: Boolean, default: false

  index({ pattern: 1 }, { unique: true })

  before_validation { self.pattern = pattern.to_s.strip.downcase }
  validates :pattern, format: { with: PATTERN }, uniqueness: true
  validate { errors.add(:admin, "needs a full address, not a domain") if admin && domain? }

  def self.admits?(email)
    matching(email).exists?
  end

  def self.admin?(email)
    matching(email).where(admin: true).exists?
  end

  # The entries that let this address in: the address itself, or its domain.
  def self.matching(email)
    email = email.to_s.strip.downcase
    return none unless email.match?(EMAIL)

    where(:pattern.in => [ email, email[email.index("@")..] ])
  end

  def domain?
    pattern.start_with?("@")
  end
end
