# frozen_string_literal: true

module Async
	module Container
		module Supervisor
			# A helper for running loops at aligned intervals.
			module Loop
				# A robust loop that executes a block at aligned intervals.
				#
				# The alignment is modulo the current clock in seconds.
				#
				# If an error occurs during the execution of the block, it is logged and the loop continues.
				#
				# @parameter interval [Integer] The interval in seconds between executions of the block.
				def self.run(interval: 60, &block)
					while true
						# Compute the wait time to the next interval:
						wait = interval - (Time.now.to_f % interval)
						if wait.positive?
							# Sleep until the next interval boundary:
							sleep(wait)
						end
						
						begin
							yield
						rescue => error
							Console.error(self, "Loop error:", error)
						end
					end
				end
			end
		end
	end
end
