# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "json"

module Async
	module Container
		module Supervisor
			class Wrapper
				def initialize(stream)
					@stream = stream
				end
				
				def write(**message)
					@stream.write(JSON.dump(message) << "\n")
					@stream.flush
				end
				
				def read
					if line = @stream.gets
						JSON.parse(line, symbolize_names: true)
					end
				end
				
				def each
					while message = read
						yield message
					end
				end
				
				def run(target)
					self.each do |message|
						action = "do_#{message[:action]}"
						target.public_send(action, self, message)
					end
				end
				
				def close
					if stream = @stream
						@stream = nil
						stream.close
					end
				end
			end
		end
	end
end
