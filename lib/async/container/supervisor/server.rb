# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "securerandom"

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
					
					@connections = {}
				end
				
				attr :monitors
				attr :connections
				
				include Dispatchable
				
				def do_register(call)
					call.connection.state.merge!(call.message[:state])
					
					connection_id = SecureRandom.uuid
					call.connection.state[:connection_id] = connection_id
					
					@connections[connection_id] = call.connection
					
					@monitors.each do |monitor|
						monitor.register(call.connection)
					rescue => error
						Console.error(self, "Error while registering process!", monitor: monitor, exception: error)
					end
				ensure
					call.finish
				end
				
				# Forward an operation to a worker connection.
				#
				# @parameter call [Connection::Call] The call to handle.
				# @parameter operation [Hash] The operation to forward, must include :do key.
				# @parameter connection_id [String] The connection ID to target.
				def do_forward(call)
					operation = call[:operation]
					connection_id = call[:connection_id]
					
					unless connection_id
						call.fail(error: "Missing 'connection_id' parameter")
						return
					end
					
					connection = @connections[connection_id]
					
					unless connection
						call.fail(error: "Connection not found", connection_id: connection_id)
						return
					end
					
					# Forward the call to the target connection
					call.forward(connection, operation)
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
					connections = @connections.map do |connection_id, connection|
						{
							connection_id: connection_id,
							process_id: connection.state[:process_id],
							state: connection.state,
						}
					end
					
					@monitors.each do |monitor|
						monitor.status(call)
					end
					
					call.finish(connections: connections)
				end
				
				def remove(connection)
					if connection_id = connection.state[:connection_id]
						@connections.delete(connection_id)
					end
					
					@monitors.each do |monitor|
						monitor.remove(connection)
					rescue => error
						Console.error(self, "Error while removing process!", monitor: monitor, exception: error)
					end
				end
				
				def run(parent: Task.current)
					parent.async do |task|
						@monitors.each do |monitor|
							monitor.run
						rescue => error
							Console.error(self, "Error while starting monitor!", monitor: monitor, exception: error)
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
