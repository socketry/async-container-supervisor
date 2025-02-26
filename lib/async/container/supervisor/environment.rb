# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "async/service/environment"

module Async
	module Container
		module Supervisor
			module Environment
				# The service class to use for the supervisor.
				# @returns [Class]
				def service_class
					Supervisor::Service
				end
				
				# The name of the supervisor
				# @returns [String]
				def name
					"supervisor"
				end
				
				# The IPC path to use for communication with the supervisor.
				# @returns [String]
				def ipc_path
					::File.expand_path("supervisor.ipc", root)
				end
				
				# The endpoint the supervisor will bind to.
				# @returns [::IO::Endpoint::Generic]
				def endpoint
					::IO::Endpoint.unix(ipc_path)
				end
				
				# Options to use when creating the container.
				def container_options
					{restart: true, count: 1, health_check_timeout: 30}
				end
				
				def monitors
					[]
				end
				
				def make_server(endpoint)
					Server.new(endpoint, monitors: self.monitors)
				end
			end
		end
	end
end
