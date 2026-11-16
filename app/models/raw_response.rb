# The page Reclame Aqui returned for a search, served back as raw_html_file.
# Kept out of Search so loading a search does not pull up to a megabyte of HTML.
class RawResponse
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  belongs_to :search, index: true
  field :body, type: String

  # Browser Rendering wraps JSON responses in Chrome's viewer markup.
  def json?
    body.to_s.lstrip.start_with?("{", "[") || body.to_s.include?("<pre")
  end
end
