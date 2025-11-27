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
				# Run a worker with the given state.
				#
				# @parameter state [Hash] The worker state (e.g. process_id, instance info).
				# @parameter endpoint [IO::Endpoint] The supervisor endpoint to connect to.
				def self.run(...)
					self.new(...).run
				end
				
				# Initialize a new worker.
				#
				# @parameter state [Hash] The worker state to register with the supervisor.
				# @parameter endpoint [IO::Endpoint] The supervisor endpoint to connect to.
				def initialize(state = nil, endpoint: Supervisor.endpoint)
					super(endpoint: endpoint)
					@state = state
				end
				
				include Dispatchable
				
				private def dump(call, buffer: true)
					if path = call[:path]
						File.open(path, "w") do |file|
							yield file
						end
						
						call.finish(path: path)
					elsif buffer
						buffer = StringIO.new
						yield buffer
						
						if message = call[:log]
							Console.info(self, message, data: buffer.string)
							call.finish
						else
							call.finish(data: buffer.string)
						end
					else
						call.fail(error: {message: "Buffered output not supported!"})
					end
				end
				
				# Dump the current fiber scheduler hierarchy.
				#
				# Generates a hierarchical view of all running fibers and their relationships.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter call[:path] [String] Optional file path to save the dump.
				def do_scheduler_dump(call)
					dump(call) do |file|
						Fiber.scheduler.print_hierarchy(file)
					end
				end
				
				# Dump the entire object space to a file.
				#
				# This is a heavyweight operation that dumps all objects in the heap.
				# Consider using {do_memory_sample} for lighter weight memory leak detection.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter call[:path] [String] Optional file path to save the dump.
				def do_memory_dump(call)
					require "objspace"
					
					dump(call, buffer: false) do |file|
						ObjectSpace.dump_all(output: file)
					end
				end
				
				# Sample memory allocations over a time period to identify potential leaks.
				#
				# This method is much lighter weight than {do_memory_dump} and focuses on
				# retained objects allocated during the sampling period. Late-lifecycle
				# allocations that are retained are likely memory leaks.
				#
				# The method samples allocations for the specified duration, forces a garbage
				# collection, and returns a JSON report showing allocated vs retained memory
				# broken down by gem, file, location, and class.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter call[:duration] [Numeric] The duration in seconds to sample for.
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
					
					report = sampler.report
					
					dump(call) do |file|
						file.puts(report.to_json)
					end
				ensure
					GC.start
				end
				
				# Dump information about all running threads.
				#
				# Includes thread inspection and backtraces for debugging.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter call[:path] [String] Optional file path to save the dump.
				def do_thread_dump(call)
					dump(call) do |file|
						Thread.list.each do |thread|
							file.puts(thread.inspect)
							file.puts(thread.backtrace)
						end
					end
				end
				
				# Start garbage collection profiling.
				#
				# Enables the GC profiler to track garbage collection performance.
				#
				# @parameter call [Connection::Call] The call to respond to.
				def do_garbage_profile_start(call)
					GC::Profiler.enable
					call.finish(started: true)
				end
				
				# Stop garbage collection profiling and return results.
				#
				# Disables the GC profiler and returns collected profiling data.
				#
				# @parameter call [Connection::Call] The call to respond to.
				# @parameter call[:path] [String] Optional file path to save the profile.
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
					# We ignore the response (it contains the `connection_id`).
				end
			end
		end
	end
end
