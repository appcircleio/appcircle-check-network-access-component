#!/usr/bin/env ruby
require 'open3'
require 'colored'
require 'shellwords'
require 'json'
require 'net/http'
require 'yaml'

DIVIDER = "-" * 6
DIVIDER_CURL = "-" * 60
BODY_SNIPPET_LEN = 800
HEADER_KEYS = %w[server content-type content-length cache-control].freeze
METRICS_FMT = %q({"code":"%{http_code}","effective_url":"%{url_effective}","time_total":"%{time_total}"})
CURL_EXIT_MESSAGES = eval(File.read(File.join(__dir__, "curl_exit_messages.rb")))

def abort_with_message(msg)
  msg.to_s.strip.split("\n").each { |line| puts "@@[error] #{line}".red }
  abort
end

def get_env_variable(key)
  v = ENV[key]
  v && !v.strip.empty? ? v : nil
end

def run_command(args)
  puts "@@[command] #{Shellwords.join(args)}".blue
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
  when /^3/ then ["Redirect — HTTP response is #{code}", :yellow]
  when /^4/ then ["Client error — HTTP response is #{code}", :red]
  when /^5/ then ["Server error — HTTP response is #{code}", :red]
  when "000" then ["Connection/timeout error", :red]
  else ["Unexpected — HTTP response is #{code}", :red]
  end
end

def classify(code, exit_status)
  return [:fail, "transport error (exit #{exit_status})"] if exit_status != 0 || code == "000"
  return [:success, "success"] if code.start_with?("2")
  return [:warn, "redirect"] if code.start_with?("3")
  return [:fail, "client error"] if code.start_with?("4")
  return [:fail, "server error"] if code.start_with?("5")
  [:fail, "unexpected"]
end

def section(text)
  return if text.to_s.empty?
  puts DIVIDER
  puts text
end

def print_result(url:, code:, is_2xx:, exit_code:, effective_url:, time_total:, headers:, body:, severity:, connect_timeout:, max_time:)
  puts "Checking: #{url}".blue
  msg, color = label_for(code)
  puts msg.send(color)
  puts "Result: #{severity.to_s.upcase}"

  return puts("#{DIVIDER_CURL}\n\n") if is_2xx

  explanation = get_better_explanation(code, exit_code, time_total, connect_timeout, max_time, effective_url)
  puts explanation unless explanation.to_s.strip.empty?

  section(headers)
  section(body)
  puts DIVIDER_CURL
  puts
end

def http_status_message(code)
  klass = Net::HTTPResponse::CODE_TO_OBJ[code.to_s]
  return "Unexpected response." unless klass
  name = klass.name.split("::").last
  msg = name.sub(/^HTTP/, "")
            .gsub(/([a-z])([A-Z])/, '\1 \2')
  msg.strip
end

def get_better_explanation(code, exit_code, time_total, connect_timeout, max_time, effective_url)
  messages = []

  exit_msg = CURL_EXIT_MESSAGES[exit_code] || "Unknown exit code"
  # Curl side
  if exit_code == 28
    if time_total.to_f >= max_time.to_f
      messages << "Curl exit #{exit_code}: Operation timed out after reaching the maximum time limit (#{max_time}s).".yellow
    elsif time_total.to_f >= connect_timeout.to_f
      messages << "Curl exit #{exit_code}: Connection could not be established within #{connect_timeout}s.".yellow
    else
      messages << "Curl exit #{exit_code}: Operation timed out.".yellow
    end
  else
    messages << "Curl exit #{exit_code}: #{exit_msg}".yellow
    messages << "Total time: #{format('%.3fs', time_total.to_f)}".yellow unless time_total.to_s.empty?
  end

  # HTTP side
  unless code.to_s == "000"
    explanation = http_status_message(code.to_i)
    color = case code
            when /^2/ then :green
            when /^3/ then :yellow
            else :red
            end
    msg = "HTTP #{code}: #{explanation}".send(color)
    msg += " -> #{effective_url}" if code.start_with?("3") && !effective_url.to_s.empty?
    messages << msg
  end

  messages.join("\n")
end

def check_endpoint(url, connect_timeout, max_time)
  tmpbody = "curl_body_#{Process.pid}.txt"
  tmphead = "curl_head_#{Process.pid}.txt"
  args = ["curl", "-s", "-o", tmpbody, "-D", tmphead, "-w", METRICS_FMT,
          "--connect-timeout", connect_timeout.to_s, "--max-time", max_time.to_s, url]

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
    severity: severity,
    connect_timeout: connect_timeout,
    max_time: max_time
  )

  File.delete(tmpbody) rescue nil
  File.delete(tmphead) rescue nil

  { code: code, severity: severity, reason: reason }
end

def addresses_from_env
  url_env_map = {
    "https://github.com/appcircleio/" => "AC_CHECK_NETWORK_GITHUB_APPCIRCLE",
    "https://rubygems.org" => "AC_CHECK_NETWORK_RUBYGEMS",
    "https://index.rubygems.org" => "AC_CHECK_NETWORK_INDEX_RUBYGEMS",
    "https://services.gradle.org" => "AC_CHECK_NETWORK_SERVICES_GRADLE_ORG",
    "https://dl.google.com/android/repository/repository2-1.xml" => "AC_CHECK_NETWORK_DL_GOOGLE_COM_ANDROID_REPOSITORY",
    "https://dl-ssl.google.com/android/repository/repository2-1.xml" => "AC_CHECK_NETWORK_DL_SSL_GOOGLE_COM_ANDROID_REPOSITORY",
    "https://maven.google.com/web/index.html" => "AC_CHECK_NETWORK_MAVEN_GOOGLE_COM",
    "https://repo1.maven.org/maven2/" => "AC_CHECK_NETWORK_REPO1_MAVEN_ORG_MAVEN2",
    "https://cdn.cocoapods.org" => "AC_CHECK_NETWORK_CDCOAPODS_ORG",
    "https://github.com/CocoaPods/Specs" => "AC_CHECK_NETWORK_GITHUB_COCOAPODS_SPECS",
    "https://firebaseappdistribution.googleapis.com/$discovery/rest?version=v1" => "AC_CHECK_NETWORK_FIREBASEAPPDISTRIBUTION_GOOGLEAPIS_COM"
  }

  urls = url_env_map.select { |_, env| get_env_variable(env) == "true" }.keys

  if (extra = get_env_variable("AC_CHECK_NETWORK_EXTRA_URL_PARAMETERS"))
    urls.concat(extra.split(",").map(&:strip).reject(&:empty?))
  end
  urls
end

def get_timeouts
  connect_timeout = get_env_variable("AC_CHECK_CONNECTION_TIMEOUT")
  max_time = get_env_variable("AC_CHECK_CONNECTION_MAX_TIMEOUT")

  connect_timeout = Integer(connect_timeout) rescue 8
  max_time = Integer(max_time) rescue 20

  if connect_timeout <= 0 || max_time <= 0
    puts "Max Timeout or Connect Timeout should have a positive value. Setting back to defaults."
    connect_timeout = 8
    max_time = 20
  end

  if max_time < connect_timeout
    abort_with_message("ERR: Max Timeout Value must be greater than Connect Timeout Value")
  end
  puts DIVIDER_CURL
  puts "Using connection timeout: #{connect_timeout} seconds"
  puts "Using max time: #{max_time} seconds"
  puts DIVIDER_CURL
  [connect_timeout, max_time]
end

def main
  connect_timeout, max_time = get_timeouts

  addresses = addresses_from_env
  if addresses.empty?
    puts "There aren't any URLs given to the component, exiting."
    exit 0
  end
  results = addresses.map { |url| [url, check_endpoint(url, connect_timeout, max_time)] }
  failed = results.select { |_, r| r[:severity] == :fail }
  unless failed.empty?
    lines = failed.map { |url, r| "#{url} — #{r[:code]} (#{r[:reason]})" }
    abort_with_message("These URLs failed:\n" + lines.join("\n"))
  end
end


main
