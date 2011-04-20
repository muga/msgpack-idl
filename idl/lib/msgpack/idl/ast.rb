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


module AST
	class Element
	end

	class Document < Array
	end

	class Include
		def initialize(path)
			@path = path
		end
		attr_reader :path
	end


	class Namespace < Element
		def initialize(scopes, lang=nil)
			@scopes = scopes
			@lang = lang
		end
		attr_reader :scopes, :lang
	end


	class Message < Element
		def initialize(name, super_class, fields)
			@name = name
			@super_class = super_class
			@fields = fields
		end
		attr_reader :name, :super_class, :fields
	end


	class Exception < Message
	end


	class Field < Element
		def initialize(id, type, modifier, name)
			@id = id
			@type = type
			@name = name
			@modifier = modifier
		end
		attr_reader :id, :type, :name, :modifier
	end

	class ValueAssignedField < Field
		def initialize(id, type, modifier, name, value)
			super(id, type, modifier, name)
			@value = value
		end
		attr_reader :value
	end


	class Enum < Element
		def initialize(name, fields)
			@name = name
			@fields = fields
		end
		attr_reader :name, :fields
	end

	class EnumField < Element
		def initialize(id, name)
			@id = id
			@name = name
		end
		attr_reader :id, :name
	end


	class Service < Element
		def initialize(name, version, funcs)
			@name = name
			@version = version
			@funcs = funcs
		end
		attr_reader :name, :version, :funcs
	end

	class Func < Element
		def initialize(name, return_type, args, exceptions)
			@name = name
			@return_type = return_type
			@args = args
			@exceptions = exceptions
		end
		attr_reader :name, :return_type, :args, :exceptions
	end


	class Application < Element
		def initialize(name, scopes)
			@name = name
			@scopes = scopes
		end

		attr_reader :name
		attr_reader :scopes
	end

	class Scope < Element
		def initialize(service, version, name, default)
			@service = service
			@version = version
			@name = name
			@default = default
		end
		attr_reader :service, :version, :name, :default

		def default?
			@default
		end
	end


	class Type < Element
		def initialize(name, nullable=false)
			@name = name
			@nullable = nullable
		end
		attr_reader :name, :nullable

		def nullable?
			@nullable
		end
	end

	class GenericType < Type
		def initialize(name, type_params, nullable=false)
			super(name, nullable)
			@type_params = type_params
		end
		attr_reader :type_params
	end

	FIELD_OPTIONAL = :optional
	FIELD_REQUIRED = :required


	class Literal
	end

	class ConstLiteral < Literal
		def initialize(name)
			@name = name
		end
		attr_reader :name
	end

	class EnumLiteral < Literal
		def initialize(name, field)
			@name = name
			@field = field
		end
		attr_reader :name, :field
	end

	class IntLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value
	end

	class FlaotLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value
	end

	class NilLiteral < Literal
	end

	class BoolLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value
	end

	class TrueLiteral < BoolLiteral
		def initialize
			super(true)
		end
	end

	class FalseLiteral < BoolLiteral
		def initialize
			super(false)
		end
	end

	class StringLiteral < Literal
		def initialize(value)
			@value = value
		end
	end

	#class ListLiteral < Literal
	#	def initialize(array)
	#		@array = array
	#	end
	#end

	#class MapLiteralPair
	#	def initialize(k, v)
	#		@key = k
	#		@value = v
	#	end
	#end

	#class MapLiteral < Literal
	#	def initialize(pairs)
	#		@pairs = pairs
	#	end
	#end


	class Sequence < Array
	end
end


end
end
