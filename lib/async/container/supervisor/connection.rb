# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"

module Async
	module Container
		module Supervisor
			class Connection
				class Call
					def initialize(connection, id, message)
						@connection = connection
						@id = id
						@message = message
						
						@queue = ::Thread::Queue.new
					end
					
					def as_json(...)
						@message
					end
					
					def to_json(...)
						as_json.to_json(...)
					end
					
					# @attribute [Connection] The connection that initiated the call.
					attr :connection
					
					# @attribute [Hash] The message that initiated the call.
					attr :message
					
					def [] key
						@message[key]
					end
					
					def push(**response)
						@queue.push(response)
					end
					
					def pop(...)
						@queue.pop(...)
					end
					
					# The call was never completed and the connection itself was closed.
					def close
						@queue.close
					end
					
					def each(&block)
						while response = self.pop
							yield response
						end
					end
					
					def finish(**response)
						# If the remote end has already closed the connection, we don't need to send a finished message:
						unless @queue.closed?
							self.push(id: @id, finished: true, **response)
							@queue.close
						end
					end
					
					def fail(**response)
						self.finish(failed: true, **response)
					end
					
					def closed?
						@queue.closed?
					end
					
					def self.dispatch(connection, target, id, message)
						Async do
							call = self.new(connection, id, message)
							connection.calls[id] = call
							
							target.dispatch(call)
							
							while response = call.pop
								connection.write(id: id, **response)
							end
						ensure
							# If the queue is closed, we don't need to send a finished message.
							unless call.closed?
								connection.write(id: id, finished: true)
							end
							
							connection.calls.delete(id)
						end
					end
					
					def self.call(connection, **message, &block)
						id = connection.next_id
						call = self.new(connection, id, message)
						
						connection.calls[id] = call
						begin
							connection.write(id: id, **message)
							
							if block_given?
								call.each(&block)
							else
								intermediate = nil
								
								while response = call.pop
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
							connection.calls.delete(id)
						end
					end
				end
				
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
				
				def next_id
					@id += 2
				end
				
				def write(**message)
					@stream.write(JSON.dump(message) << "\n")
					@stream.flush
				end
				
				def call(timeout: nil, **message)
					id = next_id
					calls[id] = ::Thread::Queue.new
					
					write(id: id, **message)
					
					return calls[id].pop(timeout: timeout)
				ensure
					calls.delete(id)
				end
				
				def read
					if line = @stream&.gets
						JSON.parse(line, symbolize_names: true)
					end
				end
				
				def each
					while message = self.read
						yield message
					end
				end
				
				def call(...)
					Call.call(self, ...)
				end
				
				def run(target)
					self.each do |message|
						if id = message.delete(:id)
							if call = @calls[id]
								# Response to a call:
								call.push(**message)
							else
								# Incoming call:
								Call.dispatch(self, target, id, message)
							end
						else
							Console.error(self, "Unknown message:", message)
						end
					end
				end
				
				def run_in_background(target, parent: Task.current)
					@reader ||= parent.async do
						self.run(target)
					end
				end
				
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
