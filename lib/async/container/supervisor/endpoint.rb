# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/endpoint/unix_endpoint"

module Async
	module Container
		module Supervisor
			def self.endpoint(path = "supervisor.ipc")
				::IO::Endpoint.unix(path)
			end
		end
	end
end
