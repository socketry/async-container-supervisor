# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "periodic_monitor"
require "memory/leak/cluster"

module Async
	module Container
		module Supervisor
			module Monitor
				class MemoryMonitor
					def initialize(interval: 10, limit: nil)
						@interval = interval
						@cluster = Memory::Leak::Cluster.new(limit: limit)
						@processes = Hash.new(0)
					end
					
					def register(wrapper, registration)
						return unless instance = registration[:instance]
						
						Console.info(self, "Registering process:", instance)
						if process_id = instance[:process_id]
							if @processes.key?(process_id)
								Console.info(self, "Incrementing process:", process_id: process_id)
								@processes[process_id] += 1
							else
								Console.info(self, "Registering process:", process_id: process_id)
								@cluster.add(process_id)
								@processes[process_id] = 1
							end
						end
					end
					
					def remove(wrapper, registration)
						return unless instance = registration[:instance]
						
						if process_id = instance[:process_id]
							if @processes.key?(process_id)
								@processes[process_id] -= 1
								
								if @processes[process_id] == 0
									Console.info(self, "Deregistering process:", process_id: process_id)
									@cluster.remove(process_id)
									@processes.delete(process_id)
								end
							end
						end
					end
					
					def run
						Async do
							while true
								Console.info(self, "Checking for memory leaks...", processes: @processes)
								@cluster.check! do |process_id, monitor|
									Console.error(self, "Memory leak detected in process:", process_id: process_id, monitor: monitor)
									::Process.kill(:INT, process_id)
								end
								
								sleep(@interval)
							end
						end
					end
				end
			end
		end
	end
end
