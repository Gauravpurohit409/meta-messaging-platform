require "fileutils"
require "securerandom"

# A blank SECRET_KEY_BASE is still truthy. Rails then aborts production boot with
# "must be a type of String". Render's free plan has no shell, so a missing or
# empty variable has to be filled in here before the app initializes.
module EnsureSecretKeyBase
  def self.apply!(env = ENV, path: default_path)
    current = env["SECRET_KEY_BASE"].to_s.strip
    return env["SECRET_KEY_BASE"] = current unless current.empty?

    stored = read_stored(path)
    env["SECRET_KEY_BASE"] = stored.empty? ? write(path) : stored
  end

  def self.default_path
    File.expand_path("../tmp/secret_key_base", __dir__)
  end

  def self.read_stored(path)
    return "" unless File.exist?(path)

    File.read(path).strip
  rescue SystemCallError
    ""
  end

  def self.write(path)
    generated = SecureRandom.hex(64)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{generated}\n")
    generated
  rescue SystemCallError
    generated
  end
  private_class_method :read_stored, :write
end
