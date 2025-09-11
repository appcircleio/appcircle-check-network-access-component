#!/usr/bin/env ruby
require 'open3'
require 'colored'
require 'shellwords'
require 'json'

DIVIDER = "-" * 30
DIVIDER_CURL = "-" * 60
BODY_SNIPPET_LEN = 600
CONNECT_TIMEOUT = "8"
MAX_TIME = "20"
HEADER_KEYS = %w[server content-type content-length cache-control].freeze
METRICS_FMT = %q({"code":"%{http_code}","effective_url":"%{url_effective}","time_total":"%{time_total}"})

CURL_EXIT_MESSAGES = {
  0 => "OK",
  1 => "Unsupported protocol",
  2 => "Failed to initialize",
  3 => "URL malformed",
  5 => "Could not resolve proxy",
  6 => "Could not resolve host",
  7 => "Failed to connect to host",
  8 => "Weird server reply",
  9 => "Access denied to a resource",
  22 => "HTTP error >= 400 returned",
  23 => "Write error",
  26 => "Read error",
  27 => "Out of memory",
  28 => "Operation timeout",
  35 => "SSL connect error",
  47 => "Too many redirects",
  51 => "SSL certificate not OK",
  52 => "Empty reply from server",
  55 => "Failed sending network data",
  56 => "Failure in receiving network data",
  60 => "Peer certificate cannot be authenticated",
  77 => "Problem with SSL CA cert",
  78 => "Resource does not exist",
  80 => "Failed to shut down SSL connection",
  82 => "Could not load CRL file",
  83 => "Issuer check failed",
  90 => "Requested TLS level failed",
  97 => "Operation failed in SSL layer",
  98 => "HTTP/3 error",
  99 => "QUIC connection error",
  100 => "Other connection setup error"
}.freeze

def abort_with_message(msg)
  msg.to_s.strip.split("\n").each { |line| puts "@@[error] #{line}".red }
  abort
end

def run_command(args)
  puts "command: #{Shellwords.join(args)}"
  stdout, _stderr, status = Open3.capture3(*args)
  { stdout: stdout, status: status.exitstatus }
end

def safe_read(path)
  return "" unless path && File.exist?(path)
  File.read(path).encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
end

def snippet(text, limit)
  s = text.to_s.strip
  return "" if s.empty?
  s.length > limit ? "#{s[0, limit]}\n(truncated)" : s
end

def pick_headers(raw_header)
  return "" if raw_header.to_s.empty?
  lines = raw_header.split("\n").map(&:strip)
  picked = [lines.first].compact
  HEADER_KEYS.each do |k|
    line = lines.find { |l| l.downcase.start_with?("#{k}:") }
    picked << line if line
  end
  picked.compact.join("\n")
end

def label_for(code)
  case code
  when /^2/ then ["HTTP response is #{code}", :green]
  when /^3/ then ["Redirect — HTTP response is #{code}", :cyan]
  when /^4/ then ["Client error — HTTP response is #{code}", :yellow]
  when /^5/ then ["Server error — HTTP response is #{code}", :red]
  when "000" then ["Connection/timeout error — HTTP response is #{code}", :red]
  else ["Unexpected — HTTP response is #{code}", :red]
  end
end

def classify(code, exit_status)
  return [:fail, "transport error (exit #{exit_status})"] if exit_status != 0 || code == "000"
  return [:ok, "ok"] if code.start_with?("2")
  return [:warn, "redirect"] if code.start_with?("3")
  return [:warn, "client error"] if code.start_with?("4")
  return [:fail, "server error"] if code.start_with?("5")
  [:fail, "unexpected"]
end

def section(text)
  return if text.to_s.empty?
  puts DIVIDER
  puts text
end

def print_result(url:, code:, is_2xx:, exit_code:, effective_url:, time_total:, headers:, body:, severity:)
  puts "Checking: #{url}"
  msg, color = label_for(code)
  puts msg.send(color)
  puts "Result: #{severity.to_s.upcase}"

  return puts("#{DIVIDER}\n\n") if is_2xx

  diag = []
  exit_msg = CURL_EXIT_MESSAGES[exit_code] || "Unknown exit code"
  diag << "curl_exit: #{exit_code} (#{exit_msg})"
  diag << "url: #{effective_url}" unless effective_url.to_s.empty?
  diag << "time_total: #{format('%.3fs', time_total.to_f)}" unless time_total.to_s.empty?

  section(diag.join("\n"))
  section(headers)
  section(body)
  puts DIVIDER_CURL
  puts
end

def check_endpoint(url)
  tmpbody = "curl_body_#{Process.pid}.txt"
  tmphead = "curl_head_#{Process.pid}.txt"
  args = ["curl", "-s", "-o", tmpbody, "-D", tmphead, "-w", METRICS_FMT,
          "--connect-timeout", CONNECT_TIMEOUT, "--max-time", MAX_TIME, url]

  res = run_command(args)
  metrics = JSON.parse(res[:stdout].strip) rescue { "code" => "000" }
  code = (metrics["code"] || "000").to_s
  is_2xx = code.start_with?("2")
  headers = pick_headers(safe_read(tmphead))
  body = is_2xx ? "" : snippet(safe_read(tmpbody), BODY_SNIPPET_LEN)
  severity, reason = classify(code, res[:status])

  print_result(
    url: url,
    code: code,
    is_2xx: is_2xx,
    exit_code: res[:status],
    effective_url: metrics["effective_url"],
    time_total: metrics["time_total"],
    headers: headers,
    body: body,
    severity: severity
  )

  File.delete(tmpbody) rescue nil
  File.delete(tmphead) rescue nil

  { code: code, severity: severity, reason: reason }
end

def addresses_from_env
  urls = []

  urls << "https://github.com/appcircleio/" if ENV["AC_CHECK_NETWORK_GITHUB_APPCIRCLE"] == "true"
  urls << "https://rubygems.org" if ENV["AC_CHECK_NETWORK_RUBYGEMS"] == "true"
  urls << "https://index.rubygems.org" if ENV["AC_CHECK_NETWORK_INDEX_RUBYGEMS"] == "true"
  urls << "https://services.gradle.org" if ENV["AC_CHECK_NETWORK_SERVICES_GRADLE_ORG"] == "true"
  urls << "https://dl.google.com/android/repository/repository2-1.xml" if ENV["AC_CHECK_NETWORK_DL_GOOGLE_COM_ANDROID_REPOSITORY"] == "true"
  urls << "https://dl-ssl.google.com/android/repository/repository2-1.xml" if ENV["AC_CHECK_NETWORK_DL_SSL_GOOGLE_COM_ANDROID_REPOSITORY"] == "true"
  urls << "https://maven.google.com/web/index.html" if ENV["AC_CHECK_NETWORK_MAVEN_GOOGLE_COM"] == "true"
  urls << "https://repo1.maven.org/maven2/" if ENV["AC_CHECK_NETWORK_REPO1_MAVEN_ORG_MAVEN2"] == "true"
  urls << "https://cdn.cocoapods.org" if ENV["AC_CHECK_NETWORK_CDCOAPODS_ORG"] == "true"
  urls << "https://github.com/CocoaPods/Specs" if ENV["AC_CHECK_NETWORK_GITHUB_COCOAPODS_SPECS"] == "true"
  urls << "https://firebaseappdistribution.googleapis.com/$discovery/rest?version=v1" if ENV["AC_CHECK_NETWORK_FIREBASEAPPDISTRIBUTION_GOOGLEAPIS_COM"] == "true"

  extra = get_env_variable("AC_CHECK_NETWORK_EXTRA_URL_PARAMETERS")
  if extra
    urls.concat(extra.split(",").map(&:strip).reject(&:empty?))
  end

  urls
end

def main
  addresses = addresses_from_env
  if addresses.empty?
    puts "There aren't any URLs given to the component, exiting."
    exit 0
  end
  results = addresses.map { |url| [url, check_endpoint(url)] }
  failed = results.select { |_, r| r[:severity] == :fail }
  unless failed.empty?
    lines = failed.map { |url, r| "#{url} — #{r[:code]} (#{r[:reason]})" }
    abort_with_message("These URLs failed:\n" + lines.join("\n"))
  end
end


main
