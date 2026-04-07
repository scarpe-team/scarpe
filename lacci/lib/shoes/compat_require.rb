# frozen_string_literal: true

# Shoes3 compatibility: case-insensitive require fallback.
# Shoes3 ran on JRuby/Windows where require was case-insensitive,
# so many legacy scripts have wrong-case requires like:
#   require 'CSV'       (should be 'csv')
#   require 'FileUtils' (should be 'fileutils')
#
# This shim catches LoadError and retries with the downcased name.

SHOES_REQUIRE_CASE_MAP = {
  "CSV" => "csv",
  "FileUtils" => "fileutils",
  "YAML" => "yaml",
  "JSON" => "json",
  "Net/HTTP" => "net/http",
  "URI" => "uri",
  "Digest" => "digest",
  "Base64" => "base64",
  "StringIO" => "stringio",
  "Tempfile" => "tempfile",
}.freeze

module Kernel
  alias_method :shoes_original_require, :require

  def require(name)
    shoes_original_require(name)
  rescue LoadError => e
    # Try the known case mapping first
    if SHOES_REQUIRE_CASE_MAP.key?(name)
      shoes_original_require(SHOES_REQUIRE_CASE_MAP[name])
    # Otherwise try downcasing if it contains uppercase letters
    elsif name =~ /[A-Z]/ && name != name.downcase
      shoes_original_require(name.downcase)
    else
      raise
    end
  end
end
