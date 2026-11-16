# One API request and its parsed result. The id doubles as the search_metadata
# id, a 24-character ObjectId like SerpApi's.
class Search
  include Mongoid::Document
  include Mongoid::Timestamps

  CACHE_TTL = 1.hour

  field :engine, type: String
  field :parameters, type: Hash
  field :fingerprint, type: String
  field :status, type: String, default: "Processing"
  field :error, type: String
  field :results, type: Hash, default: {}
  field :source_url, type: String
  field :timings, type: Hash, default: {}
  field :processed_at, type: Time

  has_one :raw_response, dependent: :delete_all

  index({ fingerprint: 1, created_at: -1 })
  index({ created_at: -1 })

  scope :created_since, ->(time) { where(:created_at.gte => time) }

  def self.fingerprint_for(parameters)
    Digest::SHA256.hexdigest(parameters.sort.to_h.to_json)
  end

  # Same rule as SerpApi: an identical search in the last hour is served from
  # storage instead of fetching Reclame Aqui again.
  def self.cached(fingerprint)
    where(fingerprint:, status: "Success", :created_at.gte => CACHE_TTL.ago).order(created_at: :desc).first
  end

  def processing?
    status == "Processing"
  end
end
