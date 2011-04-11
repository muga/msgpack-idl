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
	end

	class PrimitiveGenericType < GenericType
	end

	#class NullableType < ParameterizedType
	#	def initialize(type)
	#		@type = type
	#	end
	#	attr_reader :type
	#end

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
		def initialize(id, type, name, is_required)
			@id = id
			@type = type
			@name = name
			@is_required = is_required
		end

		attr_reader :id, :type, :name

		def required?
			@is_required
		end

		def optional?
			!@is_required
		end
	end

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
