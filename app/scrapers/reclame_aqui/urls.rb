module ReclameAqui
  module Urls
    SITE = "https://www.reclameaqui.com.br".freeze
    IOSEARCH = "https://iosearch.reclameaqui.com.br/raichu-io-site-search-v1".freeze

    module_function

    def company(company_id)
      "#{SITE}/empresa/#{escape(company_id)}/"
    end

    # The slug is cosmetic: /assistcard/_SItnLCAaPpUVPgWO/ serves the same complaint
    # as /assistcard/nao-recebi-o-reembolso..._SItnLCAaPpUVPgWO/.
    def complaint(company_id, complaint_id, slug = nil)
      path = slug.presence || "_#{complaint_id}"
      "#{SITE}/#{escape(company_id)}/#{escape(path)}/"
    end

    def segment(main, secondary = nil)
      [ "#{SITE}/segmentos", main, secondary ].compact.join("/") + "/"
    end

    def absolute(path)
      return nil if path.blank?

      URI.join("#{SITE}/", path).to_s
    end

    def company_search(query)
      "#{IOSEARCH}/companies/search/#{escape(query)}"
    end

    # Mirrors the site's own complaint list client: /query/companyComplains/{num}/{offset},
    # or /query/{q}/{num}/{offset} for a keyword search inside one company.
    def complaints(company:, num:, start:, query: nil, filters: {})
      path = query.present? ? "/query/#{escape(query)}" : "/query/companyComplains"
      params = { company: }.merge(filters.compact_blank)
      "#{IOSEARCH}#{path}/#{num}/#{start}?#{params.to_query}"
    end

    def escape(value)
      ERB::Util.url_encode(value.to_s)
    end
  end
end
