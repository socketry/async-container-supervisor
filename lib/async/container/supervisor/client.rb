# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "connection"
require_relative "dispatchable"

module Async
	module Container
		module Supervisor
			# A client provides a mechanism to connect to a supervisor server in order to execute operations.
			class Client
				# Initialize a new client.
				#
				# @parameter endpoint [IO::Endpoint] The supervisor endpoint to connect to.
				def initialize(endpoint: Supervisor.endpoint)
					@endpoint = endpoint
				end
				
				include Dispatchable
				
				protected def connect!
					peer = @endpoint.connect
					return Connection.new(peer, 0)
				end
				
				# Called when a connection is established.
				protected def connected!(connection)
					# Do nothing by default.
				end
				
				# Connect to the server.
				def connect
					connection = connect!
					connection.run_in_background(self)
					
					connected!(connection)
					
					return connection unless block_given?
					
					begin
						yield connection
					ensure
						connection.close
					end
				end
				
				# Run the client in a loop, reconnecting if necessary.
				def run
					Async(annotation: "Supervisor Client", transient: true) do
						loop do
							connection = connect!
							
							Async do
								connected!(connection)
							end
							
							connection.run(self)
						rescue => error
							Console.error(self, "Connection failed:", exception: error)
							sleep(rand)
						ensure
							connection&.close
						end
					end
				end
			end
		end
	end
end
