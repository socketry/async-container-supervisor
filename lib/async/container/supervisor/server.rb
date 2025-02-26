# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "connection"
require_relative "endpoint"

require "io/stream"

module Async
	module Container
		module Supervisor
			class Server
				def initialize(endpoint = Supervisor.endpoint, monitors: [])
					@endpoint = endpoint
					@monitors = monitors
				end
				
				attr :monitors
				
				def dispatch(call)
					method_name = "do_#{call.message[:do]}"
					self.public_send(method_name, call)
				end
				
				def do_register(call)
					call.connection.state.merge!(call.message[:state])
					
					@monitors.each do |monitor|
						begin
							monitor.register(call.connection)
						rescue => error
							Console.error(self, "Error while registering process!", monitor: monitor, exception: error)
						end
					end
				ensure
					call.finish
				end
				
				def remove(connection)
					@monitors.each do |monitor|
						begin
							monitor.remove(connection)
						rescue => error
							Console.error(self, "Error while removing process!", monitor: monitor, exception: error)
						end
					end
				end
				
				def run
					Async do |task|
						@monitors.each do |monitor|
							begin
								monitor.run
							rescue => error
								Console.error(self, "Error while starting monitor!", monitor: monitor, exception: error)
							end
						end
						
						@endpoint.accept do |peer|
							stream = IO::Stream(peer)
							connection = Connection.new(stream, 1, remote_address: peer.remote_address)
							connection.run(self)
						ensure
							connection.close
							remove(connection)
						end
						
						task.children&.each(&:wait)
					ensure
						task.stop
					end
				end
			end
		end
	end
end
