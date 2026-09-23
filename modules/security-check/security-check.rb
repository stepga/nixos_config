
#!/usr/bin/env ruby

require "csv"
require "erb"
require "fileutils"
require "open3"
require "pathname"
require "time"

BASE_DIR = Pathname.new(__dir__)
REPORT_TEMPLATE = BASE_DIR / "report.html.erb"
REPORT_CSS = BASE_DIR / "report.css"

STATE_DIR = Pathname.new(
  ENV.fetch(
    "XDG_STATE_HOME",
    File.expand_path("~/.local/state")
  )
) / "nix-security-check"
CURRENT = STATE_DIR / "current.csv"
PREVIOUS = STATE_DIR / "previous.csv"
EVIDENCE = STATE_DIR / "evidence.json"
REPORT_DIR = STATE_DIR / "report"
HTML = REPORT_DIR / "index.html"

VULNXSCAN = ENV.fetch("VULNXSCAN")

FileUtils.mkdir_p(REPORT_DIR)
FileUtils.cp(REPORT_CSS, REPORT_DIR / "report.css")
FileUtils.chmod(0o644, REPORT_DIR/"report.css")

def log(message)
  puts "[nix-security-check] #{message}"
end

def run!(*command)
  log "Running: #{command.join(" ")}"

  output, error, status =
    Open3.capture3(*command)

  unless status.success?
    warn output unless output.empty?
    warn error unless error.empty?

    abort(
      "Command failed with exit status #{status.exitstatus}"
    )
  end

  output
end

def scan
  FileUtils.rm_f(CURRENT)
  FileUtils.rm_f(EVIDENCE)

  run!(
    VULNXSCAN,
    "/run/current-system",
    "--out",
    CURRENT.to_s,
    "--evidence-out",
    EVIDENCE.to_s
  )

  unless CURRENT.file?
    abort "vulnxscan did not produce #{CURRENT}"
  end
end

def findings
  CSV.read(
    CURRENT,
    headers: true
  ).map(&:to_h)
end

def severity(row)
  Float(row["severity"] || 0)
rescue ArgumentError, TypeError
  0.0
end

def high_findings(rows)
  rows.count do |row|
    severity(row) >= 7.0
  end
end

def sources(row)
  {
    "Grype" => row["grype"],
    "OSV" => row["osv"],
    "Vulnix" => row["vulnix"]
  }.filter_map do |name, present|
    name if present == "1"
  end
end

def html_escape(value)
  ERB::Util.html_escape(value.to_s)
end

def generate_report(rows)
  template = ERB.new(REPORT_TEMPLATE.read)
  rendered = template.result(binding)
  File.write(HTML, rendered)
  FileUtils.chmod(0o644, HTML)
end

def changed?(rows)
  return true unless PREVIOUS.file?

  old = CSV.read(
    PREVIOUS,
    headers: true
  ).map(&:to_h)

  old != rows
end

def notify(rows)
  count = rows.length
  high = high_findings(rows)

  message =
    if count.zero?
      "No potential vulnerabilities found."
    elsif count == 1
      "1 potential vulnerability found."
    else
      "#{count} potential vulnerabilities found."
    end

  message += " #{high} high/critical." if high.positive?

  urgency =
    if high.positive?
      "critical"
    elsif count.positive?
      "normal"
    else
      "low"
    end

  system(
    "notify-send",
    "--urgency=#{urgency}",
    "--app-name=NixOS Security",
    "NixOS security report",
    "#{message}\n\nOpen:\n#{HTML}"
  )
end

log "Starting security scan"

scan

rows = findings

log "Findings: #{rows.length}"
log "High/Critical: #{high_findings(rows)}"
log "Report: #{HTML}"

changed = changed?(rows)

generate_report(rows)

notify(rows) if changed

FileUtils.cp(CURRENT, PREVIOUS)
FileUtils.chmod(0o644, PREVIOUS)

log "Finished"
