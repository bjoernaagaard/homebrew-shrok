# The formula published to github.com/bjoernaagaard/homebrew-shrok. The release workflow fills in the
# version, the archive URLs and their sha256 from the macOS archives it builds.
class Shrok < Formula
  desc "Personal assistant you talk to through SimpleX"
  homepage "https://github.com/bjoernaagaard/shrok"
  version "0.1.0"
  license "AGPL-3.0-only"

  on_arm do
    url "https://github.com/bjoernaagaard/shrok/releases/download/v0.1.0/shrok-0.1.0-macos-arm64.tar.gz"
    sha256 "ece2662229843599c98e0b0e4126bfae444f29263eecfb8043068f3264b74b7c"
  end

  on_intel do
    url "https://github.com/bjoernaagaard/shrok/releases/download/v0.1.0/shrok-0.1.0-macos-x64.tar.gz"
    sha256 "db0ee25fa4947d5096cacff797b4b11d36cecb4a0e2b3ed62d37e1cf15ea5222"
  end

  depends_on :macos
  depends_on "ripgrep"
  depends_on "secretspec"

  # Homebrew rewrites the ID of every dylib in the Cellar, which the bundled browser has no room for, and
  # which would break the signatures of the bundled binaries. So the app stays packed in the Cellar and the
  # post-install steps unpack it into var, where Homebrew leaves files as they are.
  def install
    system "tar", "-czf", "shrok.tar.gz", *Dir["*"]
    libexec.install "shrok.tar.gz"
    (bin/"shrok").write_env_script app/"bin/shrok", {}
  end

  post_install_steps do
    remove "shrok/app", base: :var, recursive: true
    mkdir_p "shrok/app", base: :var
    run "/usr/bin/tar",
        args: ["-xzf", "{{HOMEBREW_PREFIX}}/opt/shrok/libexec/shrok.tar.gz", "-C", "{{HOMEBREW_PREFIX}}/var/shrok/app"]
  end

  def app
    var/"shrok/app"
  end

  def caveats
    <<~EOS
      Store your model key in the macOS Keychain:
        #{Formula["secretspec"].opt_bin}/secretspec set -f #{app}/app/secretspec.toml --provider keyring:// ANTHROPIC_API_KEY
      Use this secretspec, the one the service runs, so macOS lets the service read the key without asking.
      Then start Shrok and pair your phone:
        brew services start shrok
        shrok pair
      Shrok keeps its data in ~/Library/Application Support/Shrok.
    EOS
  end

  service do
    run [
      Formula["secretspec"].opt_bin/"secretspec", "run",
      "-f", var/"shrok/app/app/secretspec.toml", "--provider", "keyring://",
      "--", opt_bin/"shrok", "run"
    ]
    keep_alive successful_exit: false
    # So the service finds gws and xurl when they are installed with Homebrew or npm.
    environment_variables PATH: std_service_path_env
    log_path var/"log/shrok.log"
    error_log_path var/"log/shrok.log"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/shrok help 2>&1", 2)
  end
end
