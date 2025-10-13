# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

source "https://rubygems.org"

gemspec

# I don't know why this is needed, but otherwise bundler in GitHub actions fails.
gem "falcon"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	
	gem "agent-context"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "decode"
	
	gem "rubocop"
	gem "rubocop-md"
	gem "rubocop-socketry"
	
	gem "sus-fixtures-async"
	
	gem "bake-test"
	gem "bake-test-external"
end
