# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "client"
require_relative "dispatchable"

module Async
	module Container
		module Supervisor
			class Worker < Client
				def self.run(...)
					self.new(...).run
				end
				
				def initialize(state, endpoint: Supervisor.endpoint)
					@state = state
					@endpoint = endpoint
				end
				
				include Dispatchable
				
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
				
				protected def connected!(connection)
					super
					
					# Register the worker with the supervisor:
					connection.call(do: :register, state: @state)
				end
			end
		end
	end
end
