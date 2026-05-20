# Per-schema namespaced filesystem storage for compact-index artifacts.
#
# Each schema gets its own root (storage/index/<schema_name>/...). Rebuilds
# of one schema never touch another schema's artifacts. In a real
# deployment this would back onto S3 with the same key layout; the disk
# implementation is sufficient for the prototype.
module CompactIndex
  class Storage
    def initialize(schema_name)
      @root = CompactIndex.storage_root.join(schema_name.to_s)
    end

    def write(path, body)
      file = absolute(path)
      FileUtils.mkdir_p(File.dirname(file))
      File.binwrite(file, body)
      body
    end

    def append(path, body)
      file = absolute(path)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "ab") { |f| f.write(body) }
      body
    end

    def read(path)
      File.binread(absolute(path))
    rescue Errno::ENOENT
      nil
    end

    def exist?(path)
      File.exist?(absolute(path))
    end

    def size(path)
      File.size(absolute(path))
    rescue Errno::ENOENT
      0
    end

    def mtime(path)
      File.mtime(absolute(path))
    rescue Errno::ENOENT
      nil
    end

    def clear!
      FileUtils.rm_rf(@root)
    end

    def absolute(path)
      @root.join(path.to_s)
    end
  end
end
