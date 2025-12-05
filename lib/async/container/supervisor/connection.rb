# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"
require "async"

module Async
	module Container
		module Supervisor
			# Represents a bidirectional communication channel between supervisor and worker.
			#
			# Handles message passing, call/response patterns, and connection lifecycle.
			class Connection
				# Represents a remote procedure call over a connection.
				#
				# Manages the call lifecycle, response queueing, and completion signaling.
				class Call
					# Initialize a new call.
					#
					# @parameter connection [Connection] The connection this call belongs to.
					# @parameter id [Integer] The unique call identifier.
					# @parameter message [Hash] The call message/parameters.
					def initialize(connection, id, message)
						@connection = connection
						@id = id
						@message = message
						
						@queue = ::Thread::Queue.new
					end
					
					# Convert the call to a JSON-compatible hash.
					#
					# @returns [Hash] The message hash.
					def as_json(...)
						@message
					end
					
					# Convert the call to a JSON string.
					#
					# @returns [String] The JSON representation.
					def to_json(...)
						as_json.to_json(...)
					end
					
					# @attribute [Connection] The connection that initiated the call.
					attr :connection
					
					# @attribute [Hash] The message that initiated the call.
					attr :message
					
					# Access a parameter from the call message.
					#
					# @parameter key [Symbol] The parameter name.
					# @returns [Object] The parameter value.
					def [] key
						@message[key]
					end
					
					# Push a response into the call's queue.
					#
					# @parameter response [Hash] The response data to push.
					def push(**response)
						@queue.push(response)
					end
					
					# Pop a response from the call's queue.
					#
					# @returns [Hash, nil] The next response or nil if queue is closed.
					def pop(...)
						@queue.pop(...)
					end
					
					# The call was never completed and the connection itself was closed.
					def close
						@queue.close
					end
					
					# Iterate over all responses from the call.
					#
					# @yields {|response| ...} Each response from the queue.
					def each(timeout: nil, &block)
						while response = self.pop(timeout: timeout)
							yield response
						end
					end
					
					# Finish the call with a final response.
					#
					# Closes the response queue after pushing the final response.
					#
					# @parameter response [Hash] The final response data.
					def finish(**response)
						# If the remote end has already closed the connection, we don't need to send a finished message:
						unless @queue.closed?
							self.push(id: @id, finished: true, **response)
							@queue.close
						end
					end
					
					# Finish the call with a failure response.
					#
					# @parameter response [Hash] The error response data.
					def fail(**response)
						self.finish(failed: true, **response)
					end
					
					# Check if the call's queue is closed.
					#
					# @returns [Boolean] True if the queue is closed.
					def closed?
						@queue.closed?
					end
					
					# Forward this call to another connection, proxying all responses back.
					#
					# This provides true streaming forwarding - intermediate responses flow through
					# in real-time rather than being buffered. The forwarding runs asynchronously
					# to avoid blocking the dispatcher.
					#
					# @parameter target_connection [Connection] The connection to forward the call to.
					# @parameter operation [Hash] The operation request to forward (must include :do key).
					def forward(target_connection, operation)
						# Forward the operation in an async task to avoid blocking
						Async do
							# Make the call to the target connection and stream responses back:
							Call.call(target_connection, **operation) do |response|
								# Push each response through our queue:
								self.push(**response)
							end
						ensure
							# Close our queue to signal completion:
							@queue.close
						end
					end
					
					# Dispatch a call to a target handler.
					#
					# Creates a call, dispatches it to the target, and streams responses back
					# through the connection.
					#
					# @parameter connection [Connection] The connection to dispatch on.
					# @parameter target [Dispatchable] The target handler.
					# @parameter id [Integer] The call identifier.
					# @parameter message [Hash] The call message.
					def self.dispatch(connection, target, id, message)
						Async do
							call = self.new(connection, id, message)
							# Track the call in the connection's calls hash:
							connection.calls[id] = call
							
							# Dispatch the call to the target (synchronously):
							target.dispatch(call)
							
							# Stream responses back to the connection (asynchronously):
							while response = call.pop
								connection.write(id: id, **response)
							end
						ensure
							# Ensure the call is removed from the connection's calls hash, otherwise it will leak:
							connection.calls.delete(id)
							
							# If the queue is closed, we don't need to send a finished message:
							unless call.closed?
								# Ensure the call is closed, to prevent messages being buffered:
								call.close
								
								# If the above write failed, this is likely to fail too, and we can safely ignore it.
								connection.write(id: id, finished: true) rescue nil
							end
						end
					end
					
					# Make a call on a connection and wait for responses.
					#
					# If a block is provided, yields each response. Otherwise, buffers intermediate
					# responses and returns the final response.
					#
					# @parameter connection [Connection] The connection to call on.
					# @parameter message [Hash] The call message/parameters.
					# @yields {|response| ...} Each intermediate response if block given.
					# @returns [Hash, Array] The final response or array of intermediate responses.
					def self.call(connection, timeout: nil, **message, &block)
						id = connection.next_id
						call = self.new(connection, id, message)
						
						connection.calls[id] = call
						begin
							connection.write(id: id, **message)
							
							if block_given?
								call.each(timeout: timeout, &block)
							else
								intermediate = nil
								
								while response = call.pop(timeout: timeout)
									if response.delete(:finished)
										if intermediate
											if response.any?
												intermediate << response
											end
											
											return intermediate
										else
											return response
										end
									else
										# Buffer intermediate responses:
										intermediate ||= []
										intermediate << response
									end
								end
							end
						ensure
							# Ensure the call is removed from the connection's calls hash, otherwise it will leak:
							connection.calls.delete(id)
							
							# Ensure the call is closed, so that `Call#pop` will return `nil`.
							call.close
						end
					end
				end
				
				# Initialize a new connection.
				#
				# @parameter stream [IO] The underlying IO stream.
				# @parameter id [Integer] The starting call ID (default: 0).
				# @parameter state [Hash] Initial connection state.
				def initialize(stream, id = 0, **state)
					@stream = stream
					@id = id
					@state = state
					
					@reader = nil
					@calls = {}
				end
				
				# @attribute [Hash(Integer, Call)] Calls in progress.
				attr :calls
				
				# @attribute [Hash(Symbol, Object)] State associated with this connection, for example the process ID, etc.
				attr_accessor :state
				
				# Generate the next unique call ID.
				#
				# @returns [Integer] The next call identifier.
				def next_id
					@id += 2
				end
				
				# Write a message to the connection stream.
				#
				# @parameter message [Hash] The message to write.
				def write(**message)
					raise IOError, "Connection is closed!" unless @stream
					@stream&.write(JSON.dump(message) << "\n")
					@stream&.flush # it is possible for @stream to become nil after the write call
				end
				
				# Read a message from the connection stream.
				#
				# @returns [Hash, nil] The parsed message or nil if stream is closed.
				def read
					if line = @stream&.gets
						JSON.parse(line, symbolize_names: true)
					end
				end
				
				# Iterate over all messages from the connection.
				#
				# @yields {|message| ...} Each message read from the stream.
				def each
					while message = self.read
						yield message
					end
				end
				
				# Make a synchronous call and wait for a single response.
				def call(...)
					Call.call(self, ...)
				end
				
				# Run the connection, processing incoming messages.
				#
				# Dispatches incoming calls to the target and routes responses to waiting calls.
				#
				# @parameter target [Dispatchable] The target to dispatch calls to.
				def run(target)
					# Process incoming messages from the connection:
					self.each do |message|
						# If the message has an ID, it is a response to a call:
						if id = message.delete(:id)
							# Find the call in the connection's calls hash:
							if call = @calls[id]
								# Enqueue the response for the call:
								call.push(**message)
							elsif message.key?(:do)
								# Otherwise, if we couldn't find an existing call, it must be a new call:
								Call.dispatch(self, target, id, message)
							else
								# Finally, if none of the above, it is likely a response to a timed-out call, so ignore it:
								Console.debug(self, "Ignoring message:", message)
							end
						else
							Console.error(self, "Unknown message:", message)
						end
					end
				end
				
				# Run the connection in a background task.
				#
				# @parameter target [Dispatchable] The target to dispatch calls to.
				# @parameter parent [Async::Task] The parent task.
				# @returns [Async::Task] The background reader task.
				def run_in_background(target, parent: Task.current)
					@reader ||= parent.async do
						self.run(target)
					end
				end
				
				# Close the connection and clean up resources.
				#
				# Stops the background reader, closes the stream, and closes all pending calls.
				def close
					if @reader
						@reader.stop
						@reader = nil
					end
					
					if stream = @stream
						@stream = nil
						stream.close
					end
					
					if @calls
						@calls.each do |id, call|
							call.close
						end
						
						@calls.clear
					end
				end
			end
		end
	end
end
