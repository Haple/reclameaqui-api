module ReclameAqui
  # Raised when a page no longer holds the data a parser expects, which usually
  # means Reclame Aqui changed its layout. Failing loudly beats returning nils.
  class ParseError < StandardError; end
end
