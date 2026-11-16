namespace :reclame_aqui do
  desc "Run one live search per engine against Reclame Aqui and check the response shape"
  task smoke: :environment do
    runner = SearchRunner.new
    failures = 0

    check = lambda do |params, keys|
      search = runner.call(ReclameAqui::Engines.build(params), no_cache: true)
      missing = keys.reject { |key| search.results[key].present? }
      ok = search.status == "Success" && search.error.nil? && missing.empty?
      failures += 1 unless ok
      puts format("%-4s %-24s %5.2fs %s", ok ? "ok" : "FAIL", params["engine"], search.timings["total_ms"].to_i / 1000.0,
        ok ? "" : [ search.error, ("missing #{missing.join(', ')}" if missing.any?) ].compact.join("; "))
      search
    end

    check.call({ "engine" => "reclame_aqui", "q" => "nubank" }, %w[companies])
    check.call({ "engine" => "reclame_aqui_company", "company_id" => "nubank" }, %w[company_info reputation reputation_by_period reputation_history main_problems])
    complaints = check.call({ "engine" => "reclame_aqui_complaints", "company_id" => "nubank", "filter" => "solved" }, %w[complaints filters])

    complaint_id = complaints.results.dig("complaints", 0, "complaint_id")
    check.call({ "engine" => "reclame_aqui_complaint", "company_id" => "nubank", "complaint_id" => complaint_id }, %w[complaint interactions]) if complaint_id

    abort "#{failures} engine(s) failed" if failures.positive?
  end
end
