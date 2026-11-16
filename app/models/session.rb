# A signed-in browser. Its id lives in a signed cookie; signing out deletes it.
class Session
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user

  field :ip_address, type: String
  field :user_agent, type: String
end
