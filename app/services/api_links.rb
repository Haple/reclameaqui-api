# Builds links back into this API, like SerpApi's serpapi_link fields.
class ApiLinks
  def initialize(base_url)
    @base_url = base_url.delete_suffix("/")
  end

  def search(params)
    "#{@base_url}/search.json?#{URI.encode_www_form(params.compact)}"
  end

  def company(company_id)
    search("engine" => "reclame_aqui_company", "company_id" => company_id)
  end

  def complaints(company_id)
    search("engine" => "reclame_aqui_complaints", "company_id" => company_id)
  end

  def complaint(company_id, complaint_id)
    search("engine" => "reclame_aqui_complaint", "company_id" => company_id, "complaint_id" => complaint_id)
  end

  def archive(search_id, format)
    "#{@base_url}/searches/#{search_id}.#{format}"
  end
end
