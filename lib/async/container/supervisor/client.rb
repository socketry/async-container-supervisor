# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/stream"
require_relative "wrapper"

module Async
	module Container
		module Supervisor
			class Client
				def self.run(...)
					self.new(...).run
				end
				
				def initialize(instance, endpoint = Supervisor.endpoint)
					@instance = instance
					@endpoint = endpoint
				end
				
				def connect
					unless @wrapper
						peer = @endpoint.connect
						stream = IO::Stream(peer)
						@wrapper = Wrapper.new(stream)
						
						@wrapper.write(action: "register", instance: @instance)
					end
					
					return @wrapper unless block_given?
					
					begin
						yield @wrapper
					ensure
						@wrapper.close
					end
				end
				
				def close
					if wrapper = @wrapper
						@wrapper = nil
						wrapper.close
					end
				end
				
				def run
					loop do
						connect do |wrapper|
							wrapper.run(self)
						end
					rescue => error
						Console.error(self, "Unexpected error while running client!", exception: error)
						
						# Retry after a small delay:
						sleep(rand)
					end
				end
			end
		end
	end
end
