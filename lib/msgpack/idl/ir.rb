#
# MessagePack IDL Processor
#
# Copyright (C) 2011 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module MessagePack
module IDL


module IR
	class Spec
		def initialize(namespace, messages, services)
			@namespace = namespace
			@messages = messages
			@services = services
		end

		attr_reader :namespace
		attr_reader :messages
		attr_reader :services
		#attr_reader :servers
		#attr_reader :clients
	end


	class ServerSpec
	end

	class ClientSpec
	end

	class TypeSpec
	end


	class Namespace < Array
	end

	class Type
		def parameterized_type?
			false
		end

		def nullable_type?
			false
		end

		def real_type
			self
		end

		def list_type?
			false
		end

		def map_type?
			false
		end
	end

	class PrimitiveType < Type
		def initialize(name)
			@name = name
		end
		attr_reader :name
	end

	class ParameterizedType < Type
		def initialize(type_params, generic_type)
			@generic_type = generic_type
			@type_params = type_params
		end
		attr_reader :type_params, :generic_type

		def name
			@generic_type.name
		end

		def parameterized_type?
			true
		end

		def list_type?
			@generic_type == Primitive.list
		end

		def map_type?
			@generic_type == Primitive.map
		end
	end

	class TypeParameterSymbol
		def initialize(name)
			@name = name
		end
		attr_reader :name
	end

	class GenericType
		def initialize(name, type_params)
			@name = name
			@type_params = type_params
		end
		attr_reader :name, :type_params

		def list_type?
			false
		end

		def map_type?
			false
		end
	end

	class PrimitiveGenericType < GenericType
	end

	class NullableType < ParameterizedType
		def initialize(type)
			super([type], Primitive.nullable)
		end

		def nullable_type?
			true
		end

		def real_type
			@type_params[0].real_type
		end
	end

	module Primitive
		def self.define(name, value)
			(class << self; self; end).module_eval {
				define_method(name) { value }
			}
		end

		define :byte,    PrimitiveType.new('byte')
		define :short,   PrimitiveType.new('short')
		define :int,     PrimitiveType.new('int')
		define :long,    PrimitiveType.new('long')
		define :ubyte,   PrimitiveType.new('ubyte')
		define :ushort,  PrimitiveType.new('ushort')
		define :uint,    PrimitiveType.new('uint')
		define :ulong,   PrimitiveType.new('ulong')
		define :float,   PrimitiveType.new('float')
		define :double,  PrimitiveType.new('double')
		define :bool,    PrimitiveType.new('bool')
		define :raw,     PrimitiveType.new('raw')
		define :string,  PrimitiveType.new('string')
		define :list,     PrimitiveGenericType.new('list', [
												TypeParameterSymbol.new('E')])
		define :map,      PrimitiveGenericType.new('map', [
												TypeParameterSymbol.new('K'),
												TypeParameterSymbol.new('V')])
		define :nullable, PrimitiveGenericType.new('nullable', [
												TypeParameterSymbol.new('T')])

		INT_TYPES = [byte, short, int, long, ubyte, ushort, uint, ulong]
	end

	class Value
	end

	class NilValue < Value
		n = NilValue.new

		(class << self; self; end).module_eval {
			define_method(:nil) { n }
		}
	end

	class BoolValue < Value
		def initialize(bool)
			@bool = bool
		end
		attr_reader :bool

		t = BoolValue.new(true)
		f = BoolValue.new(false)

		(class << self; self; end).module_eval {
			define_method(:true) { t }
			define_method(:false) { f }
		}
	end

	class IntValue < Value
		def initialize(int)
			@int = int
		end
		attr_reader :int
	end

	class EnumValue < Value
		def initialize(enum, field)
			@enum = enum
			@field = field
		end
		attr_reader :enum, :field
	end

	class EmptyValue < Value
	end

	class Message < Type
		def initialize(name, super_class, new_fields)
			@name = name
			@super_class = super_class
			@new_fields = new_fields

			if super_class
				@all_fields = super_class.all_fields + new_fields
			else
				@all_fields = new_fields
			end
			@max_id = @all_fields.map {|f| f.id }.max || 0
			@max_required_id = @all_fields.select {|f| f.required? }.map {|f| f.id }.max || 0
		end

		attr_reader :name, :super_class, :new_fields
		attr_reader :all_fields, :max_id, :max_required_id

		def [](id)
			@all_fields.find {|f| f.id == id }
		end
	end

	class Exception < Message
	end

	class Field
		def initialize(id, type, name, option, value)
			@id = id
			@type = type
			@name = name
			@option = option
			@value = value
		end

		attr_reader :id, :type, :name, :option, :value

		def required?
			@option == FIELD_REQUIRED
		end

		def optional?
			@option == FIELD_OPTIONAL
		end
	end

	FIELD_OPTIONAL = :optional
	FIELD_REQUIRED = :required

	class Enum < Type
		def initialize(name, fields)
			@name = name
			@fields = fields
		end
		attr_reader :name, :fields
	end

	class EnumField
		def initialize(id, name)
			@id = id
			@name = name
		end
		attr_reader :id, :name
	end

	class Service
		def initialize(name, versions)
			@name = name
			@versions = versions
		end
		attr_reader :name, :versions
	end

	class ServiceVersion
		def initialize(funcs, version)
			@functions = funcs
			@version = version
		end
		attr_reader :functions, :version
	end

	class Function
		def initialize(name, return_type, args)
			@name = name
			@return_type = return_type
			@args = args
			@max_id = @args.map {|a| a.id }.max || 0
			@max_id = @args.select {|a| a.required? }.map {|a| a.id }.max || 0
		end
		attr_reader :name, :return_type, :args
		attr_reader :max_id

		def super_class; nil; end
		alias new_fields args
		alias all_fields args
	end

	class Argument < Field
	end
end


end
end
