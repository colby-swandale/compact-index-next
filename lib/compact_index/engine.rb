module CompactIndex
  # Wire-syntax helpers shared by every schema.
  #
  # The engine owns delimiters and line layout. Schemas describe semantics
  # (which fields appear and in what order); they do not get to choose how
  # the bytes are arranged. This keeps the abstraction sharp — if schemas
  # could redefine syntax, the engine would degenerate into a templating
  # language.
  module Engine
    # Encode a single record into the /versions-style line.
    #
    # Records arrive as an array; the first element is the leading "key"
    # column (gem name + space-joined versions), subsequent elements are
    # space-separated columns (info checksum, then any schema additions).
    def self.encode_log_line(record)
      "#{record.join(' ')}\n"
    end

    # Encode a record for the /info/<gem>-style file.
    #
    # Format: "<version> <dep>:<req>,<dep>:<req>|<reqs>" where <reqs> is
    # comma-separated "<key>:<value>" pairs. Schemas decide which reqs
    # appear (checksum, ruby, created_at, ...); the engine joins them.
    def self.encode_info_line(version_string:, deps:, requirements:)
      dep_part = Array(deps).map { |name, req| "#{name}:#{req}" }.join(",")
      req_part = Array(requirements).map { |k, v| "#{k}:#{v}" }.join(",")
      "#{version_string} #{dep_part}|#{req_part}\n"
    end

    # Standard /info file preamble.
    def self.info_header
      "---\n"
    end

    # Standard /names file preamble.
    def self.names_header
      "---\n"
    end
  end
end
