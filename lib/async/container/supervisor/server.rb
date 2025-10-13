# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "connection"
require_relative "endpoint"
require_relative "dispatchable"

module Async
	module Container
		module Supervisor
			# The server represents the main supervisor process which is responsible for managing the lifecycle of other processes.
			#
			# There are various tasks that can be executed by the server, such as restarting the process group, and querying the status of the processes. The server is also responsible for managing the lifecycle of the monitors, which can be used to monitor the status of the connected workers.
			class Server
				def initialize(monitors: [], endpoint: Supervisor.endpoint)
					@monitors = monitors
					@endpoint = endpoint
				end
				
				attr :monitors
				
				include Dispatchable
				
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
				
				# Restart the current process group, usually including the supervisor and any other processes.
				#
				# @parameter signal [Symbol] The signal to send to the process group.
				def do_restart(call)
					signal = call[:signal] || :INT
					
					# We are going to terminate the progress group, including *this* process, so finish the current RPC before that:
					call.finish
					
					::Process.kill(signal, ::Process.ppid)
				end
				
				def do_status(call)
					@monitors.each do |monitor|
						monitor.status(call)
					end
					
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
				
				def run(parent: Task.current)
					parent.async do |task|
						@monitors.each do |monitor|
							begin
								monitor.run
							rescue => error
								Console.error(self, "Error while starting monitor!", monitor: monitor, exception: error)
							end
						end
						
						@endpoint.accept do |peer|
							connection = Connection.new(peer, 1)
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
