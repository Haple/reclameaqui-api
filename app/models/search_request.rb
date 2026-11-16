# One call to /search.json by a guest, served from cache or not. A Search is
# shared by everyone who asks the same thing within the hour; this records who
# asked, for the admin page.
class SearchRequest
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  belongs_to :user
  belongs_to :search

  field :engine, type: String
  field :parameters, type: Hash
  field :cached, type: Boolean, default: false
  field :via, type: String

  index({ created_at: -1 })
  index({ user_id: 1, created_at: -1 })

  def self.record(search, user:, via:)
    create!(search:, user:, engine: search.engine, parameters: search.parameters, cached: search.from_cache?, via:)
  end
end
