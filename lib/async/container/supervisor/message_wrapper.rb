# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "msgpack"

module Async
	module Container
		module Supervisor
			class MessageWrapper
				def initialize(stream)
					@factory = MessagePack::Factory.new
					
					register_types
					
					@packer = @factory.packer(stream)
					@unpacker = @factory.unpacker(stream)
				end
				
				def write(message)
					data = pack(message)
					# Console.logger.info("Sending data: #{message.inspect}")
					@packer.write(data)
				end
				
				def read
					data = @unpacker.read
					# Console.logger.info("Received data: #{data.inspect}")
					data
				end
				
				def pack(message)
					@packer.clear
					normalized_message = normalize(message)
					@packer.pack(normalized_message)
					@packer.full_pack
				end
				
				def unpack(data)
					@factory.unpack(data)
				end
				
				private
				
				def normalize(obj)
					case obj
					when Hash
						obj.transform_values{|v| normalize(v)}
					when Array
						obj.map{|v| normalize(v)}
					else
						if obj.respond_to?(:as_json)
							normalize(obj.as_json)
						else
							obj
						end
					end
				end
				
				def register_types
					@factory.register_type(0x00, Symbol)
					
					@factory.register_type(
						0x01,
						Exception,
						packer: self.method(:pack_exception),
						unpacker: self.method(:unpack_exception),
						recursive: true,
					)
					
					@factory.register_type(
						0x02,
						Class,
						packer: ->(klass) {klass.name},
						unpacker: ->(name) {name},
					)
					
					@factory.register_type(
						MessagePack::Timestamp::TYPE,
						Time,
						packer: MessagePack::Time::Packer,
						unpacker: MessagePack::Time::Unpacker
					)
				end
				
				def pack_exception(exception)
					[exception.class.name, exception.message, exception.backtrace].pack("A*")
				end
				
				def unpack_exception(data)
					klass, message, backtrace = data.unpack("A*A*A*")
					klass = Object.const_get(klass)
					
					exception = klass.new(message)
					exception.set_backtrace(backtrace)
					
					return exception
				end
			end
		end
	end
end
