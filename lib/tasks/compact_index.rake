namespace :compact_index do
  desc "Rebuild one schema's artifacts from scratch (e.g. bin/rake compact_index:backfill[v2])"
  task :backfill, [ :schema ] => :environment do |_t, args|
    schema_name = args[:schema] or abort "usage: bin/rake compact_index:backfill[v1|v2|v3|all]"

    targets = schema_name == "all" ? CompactIndex.schema_names : [ schema_name ]

    targets.each do |name|
      puts "Backfilling #{name}..."
      schema = CompactIndex.schema(name)
      CompactIndex::Indexer.new(schema).rebuild!
      puts "  done."
    end
  end

  desc "Show per-schema cursor + lag status"
  task status: :environment do
    max_at = [
      Version.maximum(:updated_at),
      Rubygem.maximum(:updated_at),
      BuildArtifact.maximum(:updated_at)
    ].compact.max
    puts "Canonical max updated_at: #{max_at&.utc&.iso8601 || '(empty)'}"
    puts ""

    CompactIndex.schema_names.each do |name|
      cursor = IndexCursor.for(name)
      puts "[#{name}]"
      puts "  paused:            #{cursor.paused}"
      puts "  last_processed_at: #{cursor.last_processed_at&.utc&.iso8601 || '(never)'}"
      puts "  lag_seconds:       #{cursor.lag_seconds || '(unknown)'}"
      puts "  resources:         #{CompactIndex.schema(name).resources.keys.join(', ')}"
      puts ""
    end
  end

  desc "Pause one schema's indexer (e.g. bin/rake compact_index:pause[v2])"
  task :pause, [ :schema ] => :environment do |_t, args|
    cursor = IndexCursor.for(args.fetch(:schema))
    cursor.update!(paused: true)
    puts "Paused: #{cursor.schema_name}"
  end

  desc "Resume one schema's indexer"
  task :resume, [ :schema ] => :environment do |_t, args|
    cursor = IndexCursor.for(args.fetch(:schema))
    cursor.update!(paused: false)
    puts "Resumed: #{cursor.schema_name}"
  end
end
