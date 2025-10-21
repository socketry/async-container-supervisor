# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async"
require "async/service/generic"
require "io/endpoint/bound_endpoint"

module Async
	module Container
		module Supervisor
			# The supervisor service implementation.
			#
			# Manages the lifecycle of the supervisor server and its monitors.
			class Service < Async::Service::Generic
				# Initialize the supervisor using the given environment.
				# @parameter environment [Build::Environment]
				def initialize(...)
					super
					
					@bound_endpoint = nil
				end
				
				# The endpoint which the supervisor will bind to.
				# Typically a unix pipe in the same directory as the host.
				def endpoint
					@evaluator.endpoint
				end
				
				# Bind the supervisor to the specified endpoint.
				def start
					@bound_endpoint = self.endpoint.bound
					
					super
				end
				
				# Get the name of the supervisor service.
				#
				# @returns [String] The service name.
				def name
					@evaluator.name
				end
				
				# Set up the supervisor service in the container.
				#
				# Creates and runs the supervisor server with configured monitors.
				#
				# @parameter container [Async::Container::Generic] The container to set up in.
				def setup(container)
					container_options = @evaluator.container_options
					health_check_timeout = container_options[:health_check_timeout]
					
					container.run(name: self.name, **container_options) do |instance|
						evaluator = @environment.evaluator
						
						Async do
							server = evaluator.make_server(@bound_endpoint)
							server.run
							
							instance.ready!
							
							if health_check_timeout
								Async(transient: true) do
									while true
										sleep(health_check_timeout / 2)
										instance.ready!
									end
								end
							end
						end
					end
					
					super
				end
				
				# Release the bound endpoint.
				def stop
					@bound_endpoint&.close
					@bound_endpoint = nil
					
					super
				end
			end
		end
	end
end
