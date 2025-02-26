# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async/scheduler_context"
require "async/container/supervisor"

require "io/endpoint/bound_endpoint"
require "tmpdir"

module Async
	module Container
		module Supervisor
			class RegistrationMonitor
				def initialize
					@registrations = []
				end
				
				attr :registrations
				
				def run
				end
				
				def register(connection)
					@registrations << connection
				end
				
				def remove(connection)
					@registrations.delete(connection)
				end
			end
			
			AServer = Sus::Shared("a server") do
				include Sus::Fixtures::Async::SchedulerContext
				
				let(:ipc_path) {File.join(@root, "supervisor.ipc")}
				let(:endpoint) {Async::Container::Supervisor.endpoint(ipc_path)}
				
				def around(&block)
					Dir.mktmpdir do |directory|
						@root = directory
						super(&block)
					end
				end
				
				let(:registration_monitor) {RegistrationMonitor.new}
				let(:monitors) {[registration_monitor]}
				let(:server) {Async::Container::Supervisor::Server.new(@bound_endpoint, monitors: monitors)}
				
				before do
					@bound_endpoint = endpoint.bound
					
					@server_task = reactor.async do
						server.run
					end
				end
				
				after do
					@server_task&.stop
					@bound_endpoint&.close
				end
			end
		end
	end
end
