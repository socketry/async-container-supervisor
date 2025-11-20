# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "msgpack"
require "set"

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
					@packer.write(data)
				end
				
				def read
					@unpacker.read
				end
				
				def pack(message)
					@packer.clear
					normalized_message = normalize(message, Set.new)
					@packer.pack(normalized_message)
					@packer.full_pack
				end
				
				def unpack(data)
					@factory.unpack(data)
				end
				
				private
				
				def normalize(obj, visited = Set.new.compare_by_identity)
					# Check for circular references
					return "..." if visited.include?(obj)
					
					case obj
					when Hash
						visited.add(obj)
						result = obj.transform_values{|v| normalize(v, visited)}
						visited.delete(obj)
						result
					when Array
						visited.add(obj)
						result = obj.map{|v| normalize(v, visited)}
						visited.delete(obj)
						result
					else
						if obj.respond_to?(:as_json) && (as_json = obj.as_json) && as_json != obj
							visited.add(obj)
							result = normalize(as_json, visited)
							visited.delete(obj)
							result
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
				
				def pack_exception(exception, packer)
					message = [exception.class.name, exception.message, exception.backtrace]
					packer.write(message)
				end
				
				def unpack_exception(unpacker)
					klass, message, backtrace = unpacker.read
					klass = Object.const_get(klass)
					
					exception = klass.new(message)
					exception.set_backtrace(backtrace)
					
					return exception
				end
			end
		end
	end
end
