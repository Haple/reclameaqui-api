module ReclameAqui
  # Turns the site's display values into plain JSON types.
  module Normalize
    TIME_ZONE = "America/Sao_Paulo".freeze

    STATUS_LABELS = {
      "RA1000" => "RA1000",
      "GREAT" => "Ótima",
      "GOOD" => "Boa",
      "REGULAR" => "Regular",
      "BAD" => "Ruim",
      "NOT_RECOMMENDED" => "Não recomendada",
      "UNDER_REVIEW" => "Em análise",
      "SUSPENDED" => "Suspensa",
      "BAD_ANSWERED" => "Resposta ruim",
      "NO_INDEX" => "Sem índice"
    }.freeze

    MONTHS = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

    module_function

    # "8.4", "98,3%" and 7 become numbers; "--", "" and nil become nil.
    def number(value)
      return value if value.is_a?(Numeric)

      text = value.to_s.strip.delete("%").tr(",", ".")
      return nil unless text.match?(/\A-?\d+(\.\d+)?\z/)

      text.include?(".") ? text.to_f : text.to_i
    end

    def integer(value)
      number(value)&.round
    end

    # Reclame Aqui stores Brasília local time. List payloads send it bare
    # ("2026-11-16T06:54:04") and complaint pages append a "Z" that is not UTC
    # (the site's own "Há 20h" labels only add up as -03:00). Both are read as
    # -03:00 so every timestamp this API returns means the same instant.
    def time(value)
      return nil if value.blank?

      local = value.to_s.sub(/(\.\d+)?Z\z/, "")
      Time.find_zone!(TIME_ZONE).parse(local)&.iso8601
    rescue ArgumentError
      nil
    end

    def date(value)
      time(value)&.first(10)
    end

    def cnpj(value)
      digits = value.to_s.gsub(/\D/, "")
      return nil unless digits.size == 14

      "#{digits[0, 2]}.#{digits[2, 3]}.#{digits[5, 3]}/#{digits[8, 4]}-#{digits[12, 2]}"
    end

    def status_label(code)
      STATUS_LABELS[code]
    end

    # The list payload says ANSWERED for a complaint the complaint page calls
    # SOLVED, so the badge is derived from the evaluation flags instead.
    def complaint_status(status, evaluated:, solved:)
      if evaluated
        solved ? %w[solved Resolvido] : [ "not_solved", "Não resolvido" ]
      elsif status == "PENDING"
        [ "not_answered", "Não respondida" ]
      else
        %w[answered Respondida]
      end
    end

    # "Mai 2026" becomes "2026-05".
    def month(label)
      name, year = label.to_s.split
      index = MONTHS.index(name.to_s.downcase)
      index && year ? format("%s-%02d", year, index + 1) : nil
    end

    # 592736.0 seconds becomes "6 dias e 21 horas", the way the site displays
    # average response times (whole days, then hours rounded to the nearest one).
    def duration_text(seconds)
      seconds = number(seconds)
      return nil if seconds.nil?

      days, rest = seconds.divmod(86_400)
      hours = (rest / 3600.0).round
      days, hours = days + 1, 0 if hours == 24
      parts = []
      parts << "#{days.to_i} #{days == 1 ? 'dia' : 'dias'}" if days.positive?
      parts << "#{hours} #{hours == 1 ? 'hora' : 'horas'}" if hours.positive? || parts.empty?
      parts.join(" e ")
    end

    # Complaints, replies and alerts arrive as HTML ("Prezada Renata,<br /><br />...").
    def text(html)
      return nil if html.blank?

      breaks = html.gsub(%r{<br\s*/?>}i, "\n").gsub(%r{</p>}i, "\n\n")
      Nokogiri::HTML5.fragment(breaks).text.gsub(/[ \t]+$/, "").gsub(/\n{3,}/, "\n\n").strip.presence
    end

    # Keys missing from the page are left out of the JSON instead of being sent as
    # null, but false and 0 stay.
    def prune(hash)
      hash.reject { |_, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
    end
  end
end
