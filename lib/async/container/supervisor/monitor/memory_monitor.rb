# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "periodic_monitor"
require "memory/leaks/cluster"

module Async
	module Container
		module Supervisor
			module Monitor
				class MemoryMonitor < PeriodicMonitor
					def initialize(cluster, **options)
						super(**options)
						@cluster = cluster
						@processes = Hash.new
					end
					
					def register(wrapper, message)
						if process_id = message[:process_id]
							if @processes.key?(process_id)
								@processes[process_id] += 1
							else
								@cluster.add(process_id)
								@processes[process_id] = 1
							end
						end
					end
					
					def remove()
						# if 
						@cluster.remove(worker.process_id)
					end
					
					def call
						@cluster.check! do |pid, monitor|
							kill(pid)
						end
					end
					
					def run
						while true
							self.call
							
							sleep(@interval)
						end
					end
				end
			end
		end
	end
end
