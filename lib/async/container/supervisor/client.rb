# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/stream"
require_relative "connection"

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
				
				def dispatch(call)
					method_name = "do_#{call.message[:do]}"
					self.public_send(method_name, call)
				end
				
				def connect
					unless @connection
						peer = @endpoint.connect
						stream = IO::Stream(peer)
						@connection = Connection.new(stream, 0, instance: @instance)
						
						# Register the instance with the server:
						Async do
							@connection.call(do: :register, state: @instance)
						end
					end
					
					return @connection unless block_given?
					
					begin
						yield @connection
					ensure
						@connection.close
					end
				end
				
				def close
					if connection = @connection
						@connection = nil
						connection.close
					end
				end
				
				private def dump(call)
					if path = call[:path]
						File.open(path, "w") do |file|
							yield file
						end
						
						call.finish(path: path)
					else
						buffer = StringIO.new
						yield buffer
						
						call.finish(data: buffer.string)
					end
				end
				
				def do_scheduler_dump(call)
					dump(call) do |file|
						Fiber.scheduler.print_hierarchy(file)
					end
				end
				
				def do_memory_dump(call)
					require "objspace"
					
					dump(call) do |file|
						ObjectSpace.dump_all(output: file)
					end
				end
				
				def do_thread_dump(call)
					dump(call) do |file|
						Thread.list.each do |thread|
							file.puts(thread.inspect)
							file.puts(thread.backtrace)
						end
					end
				end
				
				def do_garbage_profile_start(call)
					GC::Profiler.enable
					call.finish(started: true)
				end
				
				def do_garbage_profile_stop(call)
					GC::Profiler.disable
					
					dump(connection, message) do |file|
						file.puts GC::Profiler.result
					end
				end
				
				def run
					Async do |task|
						loop do
							connect do |connection|
								connection.run(self)
							end
						rescue => error
							Console.error(self, "Unexpected error while running client!", exception: error)
							
							# Retry after a small delay:
							sleep(rand)
						end
					ensure
						task.stop
					end
				end
			end
		end
	end
end
