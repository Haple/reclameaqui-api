class PlaygroundController < ApplicationController
  EXAMPLES = {
    "reclame_aqui" => [ { "q" => "nubank" }, { "q" => "123 milhas" }, { "q" => "enel" } ],
    "reclame_aqui_company" => [ { "company_id" => "nubank" }, { "company_id" => "shein" }, { "company_id" => "hotel-urbano" }, { "company_id" => "assistcard" } ],
    "reclame_aqui_complaints" => [
      { "company_id" => "assistcard", "filter" => "solved" },
      { "company_id" => "nubank", "q" => "pix" },
      { "company_id" => "shein", "filter" => "not_answered" }
    ],
    "reclame_aqui_complaint" => [ { "company_id" => "assistcard", "complaint_id" => "SItnLCAaPpUVPgWO" } ]
  }.freeze

  def show
    @config = {
      engines: ReclameAqui::Engines.all.map do |engine|
        {
          name: engine.engine_name,
          title: engine.title,
          params: engine.params_spec.map(&:to_h).map { |param| param.except(:format) },
          examples: EXAMPLES.fetch(engine.engine_name),
          xray: engine.xray
        }
      end
    }
  end
end
