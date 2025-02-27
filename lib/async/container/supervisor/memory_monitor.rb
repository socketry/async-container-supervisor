# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "memory/leak/cluster"
require "set"

module Async
	module Container
		module Supervisor
			class MemoryMonitor
				def initialize(interval: 10, limit: nil, &block)
					@interval = interval
					@cluster = Memory::Leak::Cluster.new(limit: limit)
					@processes = Hash.new{|hash, key| hash[key] = Set.new.compare_by_identity}
				end
				
				def register(connection)
					if process_id = connection.state[:process_id]
						connections = @processes[process_id]
						
						if connections.empty?
							Console.info(self, "Registering process:", process_id: process_id)
							@cluster.add(process_id)
						end
						
						connections.add(connection)
					end
				end
				
				def remove(connection)
					if process_id = connection.state[:process_id]
						connections = @processes[process_id]
						
						connections.delete(connection)
						
						if connections.empty?
							Console.info(self, "Removing process:", process_id: process_id)
							@cluster.remove(process_id)
						end
					end
				end
				
				def status(call)
					call.push(memory_monitor: @cluster)
				end
				
				def run
					Async do
						while true
							@cluster.check! do |process_id, monitor|
								Console.error(self, "Memory leak detected in process:", process_id: process_id, monitor: monitor)
								connections = @processes[process_id]
								
								connections.each do |connection|
									path = "/tmp/memory_dump_#{process_id}.json"
									
									response = connection.call(do: :memory_dump, path: path, timeout: 30)
									Console.info(self, "Memory dump saved to:", path, response: response)
									@block.call(response) if @block
								end
								
								# Kill the process:
								Console.info(self, "Killing process:", process_id: process_id)
								Process.kill(:INT, process_id)
							end
							
							sleep(@interval)
						end
					end
				end
			end
		end
	end
end
