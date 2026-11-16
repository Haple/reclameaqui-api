# Maps a company slug ("assistcard") to Reclame Aqui's internal id ("29260"),
# which the complaint list endpoint requires. Filled from every search result
# that shows both, so most lookups never cost a fetch.
class KnownCompany
  include Mongoid::Document
  include Mongoid::Timestamps

  field :company_id, type: String
  field :reclame_aqui_id, type: String

  index({ company_id: 1 }, unique: true)

  def self.remember(pairs)
    pairs.each do |company_id, reclame_aqui_id|
      next if company_id.blank? || reclame_aqui_id.blank?

      where(company_id:).find_one_and_update({ "$set" => { reclame_aqui_id:, updated_at: Time.current } }, upsert: true)
    end
  end

  # Falls back to fetching the company page, which carries the id.
  def self.resolve(company_id, client:)
    known = where(company_id:).first&.reclame_aqui_id
    return known if known

    results = ReclameAqui::Parsers::CompanyPage.parse(client.fetch(ReclameAqui::Urls.company(company_id)).body)
    raise ReclameAqui::NotFound, results[:error] if results[:error]

    results.dig(:company_info, :id).tap { |id| remember([ [ company_id, id ] ]) }
  end
end
