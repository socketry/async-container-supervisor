# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/leak/cluster"
require "set"

module Async
	module Container
		module Supervisor
			class MemoryMonitor
				# Create a new memory monitor.
				#
				# @parameter interval [Integer] The interval at which to check for memory leaks.
				# @parameter total_size_limit [Integer] The total size limit of all processes, or nil for no limit.
				# @parameter options [Hash] Options to pass to the cluster when adding processes.
				def initialize(interval: 10, total_size_limit: nil, **options)
					@interval = interval
					@cluster = Memory::Leak::Cluster.new(total_size_limit: total_size_limit)
					
					# We use these options when adding processes to the cluster:
					@options = options
					
					@processes = Hash.new{|hash, key| hash[key] = Set.new.compare_by_identity}
				end
				
				# Add a process to the memory monitor. You may override this to control how processes are added to the cluster.
				#
				# @parameter process_id [Integer] The process ID to add.
				def add(process_id)
					@cluster.add(process_id, **@options)
				end
				
				# Register the connection (worker) with the memory monitor.
				def register(connection)
					Console.debug(self, "Registering connection:", connection: connection, state: connection.state)
					if process_id = connection.state[:process_id]
						connections = @processes[process_id]
						
						if connections.empty?
							Console.debug(self, "Registering process:", process_id: process_id)
							self.add(process_id)
						end
						
						connections.add(connection)
					end
				end
				
				# Remove the connection (worker) from the memory monitor.
				def remove(connection)
					if process_id = connection.state[:process_id]
						connections = @processes[process_id]
						
						connections.delete(connection)
						
						if connections.empty?
							Console.debug(self, "Removing process:", process_id: process_id)
							@cluster.remove(process_id)
						end
					end
				end
				
				# Dump the current status of the memory monitor.
				#
				# @parameter call [Connection::Call] The call to respond to.
				def status(call)
					call.push(memory_monitor: @cluster)
				end
				
				# Invoked when a memory leak is detected.
				#
				# @parameter process_id [Integer] The process ID of the process that has a memory leak.
				# @parameter monitor [Memory::Leak::Monitor] The monitor that detected the memory leak.
				# @returns [Boolean] True if the process was killed.
				def memory_leak_detected(process_id, monitor)
					Console.info(self, "Killing process:", process_id: process_id)
					Process.kill(:INT, process_id)
					
					true
				end
				
				# Run the memory monitor.
				#
				# @returns [Async::Task] The task that is running the memory monitor.
				def run
					Async do
						while true
							# This block must return true if the process was killed.
							@cluster.check! do |process_id, monitor|
								Console.error(self, "Memory leak detected in process:", process_id: process_id, monitor: monitor)
								memory_leak_detected(process_id, monitor)
							end
							
							sleep(@interval)
						end
					end
				end
			end
		end
	end
end
