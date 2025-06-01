# frozen_string_literal: true

require_relative "lib/async/container/supervisor/version"

Gem::Specification.new do |spec|
	spec.name = "async-container-supervisor"
	spec.version = Async::Container::Supervisor::VERSION
	
	spec.summary = "A supervisor for managing multiple container processes."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/async-container-supervisor"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-container-supervisor/",
		"source_code_uri" => "https://github.com/socketry/async-container-supervisor.git",
	}
	
	spec.files = Dir.glob(["{bake,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async-container", "~> 0.22"
	spec.add_dependency "async-service"
	spec.add_dependency "io-endpoint"
	spec.add_dependency "io-stream"
	spec.add_dependency "memory-leak", "~> 0.5"
end
