# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/stream"

require_relative "wrapper"
require_relative "endpoint"

module Async
	module Container
		module Supervisor
			class Server
				def initialize(endpoint = Supervisor.endpoint, monitors: [])
					@endpoint = endpoint
					
					@registered = Hash.new.compare_by_identity
					
					@monitors = monitors
				end
				
				attr :monitors
				
				# @attribute [Hash(Wrapper, Message)]
				attr :registered
				
				def do_register(wrapper, state)
					@registered[wrapper] = state
					
					@monitors.each do |monitor|
						monitor.register(wrapper, state)
					end
				end
				
				def remove(wrapper)
					state = @registered.delete(wrapper)
					
					@monitors.each do |monitor|
						monitor.remove(wrapper, state)
					end
				end
				
				def run
					@endpoint.accept do |peer|
						stream = IO::Stream(peer)
						wrapper = Wrapper.new(stream)
						wrapper.run(self)
					ensure
						wrapper.close
						remove(wrapper)
					end
				end
			end
		end
	end
end
