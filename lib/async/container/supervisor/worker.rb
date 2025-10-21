# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "client"
require_relative "dispatchable"

module Async
	module Container
		module Supervisor
			# A worker represents a long running process that can be controlled by the supervisor.
			#
			# There are various tasks that can be executed by the worker, such as dumping memory, threads, and garbage collection profiles.
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
				
				# Sample memory allocations over a time period to identify potential leaks.
				#
				# This method is much lighter weight than {do_memory_dump} and focuses on
				# retained objects allocated during the sampling period. Late-lifecycle
				# allocations that are retained are likely memory leaks.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter duration [Numeric] The duration in seconds to sample for (default: 10).
				def do_memory_sample(call)
					require "memory"
					
					unless duration = call[:duration] and duration.positive?
						raise ArgumentError, "Positive duration is required!"
					end
					
					Console.info(self, "Starting memory sampling...", duration: duration)
					
					# Create a sampler to track allocations
					sampler = Memory::Sampler.new
					
					# Start sampling
					sampler.start
					
					# Sample for the specified duration
					sleep(duration)
					
					# Stop sampling
					sampler.stop
					
					Console.info(self, "Memory sampling completed, generating report...", sampler: sampler)
					
					# Generate a report focused on retained objects (likely leaks):
					report = sampler.report
					call.finish(report: report.as_json)
				ensure
					GC.start
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
					dump(connection, message) do |file|
						file.puts GC::Profiler.result
					end
				ensure
					GC::Profiler.disable
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
