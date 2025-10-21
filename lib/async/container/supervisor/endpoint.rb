# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/endpoint/unix_endpoint"

module Async
	module Container
		module Supervisor
			# Get the supervisor IPC endpoint.
			#
			# @parameter path [String] The path for the Unix socket (default: "supervisor.ipc").
			# @returns [IO::Endpoint] The Unix socket endpoint.
			def self.endpoint(path = "supervisor.ipc")
				::IO::Endpoint.unix(path)
			end
		end
	end
end
