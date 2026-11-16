# Fixtures are real responses captured through Browser Rendering on 2026-11-16,
# stored exactly as returned (JSON endpoints still wrapped in Chrome's viewer).
module FixtureHelpers
  FIXTURES = Rails.root.join("spec/fixtures/reclame_aqui")

  def fixture(path)
    FIXTURES.join(path).read
  end

  def json_fixture(path)
    ReclameAqui::JsonDocument.parse(fixture(path))
  end
end
