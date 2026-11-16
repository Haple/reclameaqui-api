class PagesController < ApplicationController
  def home
    links = ApiLinks.new(request.base_url)
    @engines = ReclameAqui::Engines.all
    @example = DocsExample.response("reclame_aqui_company", links).slice("search_metadata", "search_parameters", "company_info", "reputation")
    @example["company_info"] = @example["company_info"].slice("id", "company_id", "name", "cnpj", "verified", "link")
    @example_url = links.search(DocsExample.params("reclame_aqui_company"))
  end
end
