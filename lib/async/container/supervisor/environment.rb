# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/service/environment"

require_relative "service"

module Async
	module Container
		module Supervisor
			# An environment mixin for supervisor services.
			#
			# Provides configuration and setup for supervisor processes that monitor workers.
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
				
				# Get the list of monitors to run in the supervisor.
				#
				# Override this method to provide custom monitors.
				#
				# @returns [Array] The list of monitor instances.
				def monitors
					[]
				end
				
				# Create the supervisor server instance.
				#
				# @returns [Server] The supervisor server.
				def make_server(endpoint)
					Server.new(endpoint: endpoint, monitors: self.monitors)
				end
			end
		end
	end
end
