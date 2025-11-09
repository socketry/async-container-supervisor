# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"

module Async
	module Container
		module Supervisor
			AMonitor = Sus::Shared("a monitor") do
				include_context AServer
				
				let(:monitors) {[monitor, registration_monitor]}
				
				it "can add and remove connections" do
					worker = Worker.new(endpoint: endpoint)
					connection = worker.connect
					
					event = registration_monitor.pop
					expect(event).to have_attributes(
						type: be == :register,
					)
					
					connection.close
					
					event = registration_monitor.pop
					expect(event).to have_attributes(
						type: be == :remove,
					)
				end
			end
		end
	end
end
