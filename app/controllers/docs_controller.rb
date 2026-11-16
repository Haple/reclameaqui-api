class DocsController < ApplicationController
  allow_unauthenticated_access

  def show
    @engines = ReclameAqui::Engines.all
    @links = ApiLinks.new(request.base_url)
    return render :index if params[:engine].blank?

    @engine = ReclameAqui::Engines.fetch(params[:engine])
    @example_url = @links.search(DocsExample.params(@engine.engine_name))
    @example = DocsExample.response(@engine.engine_name, @links)
  rescue ReclameAqui::Engines::InvalidParams
    raise ActionController::RoutingError, "No such engine"
  end
end
