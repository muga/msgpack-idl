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
	SUMMARY_LINES = 6

	class Element
		alias text to_s

		def summary
			t = text
			lines = t.split("\n")
			return t if lines.size <= SUMMARY_LINES
			if lines.last == "}"
				(lines[0,SUMMARY_LINES-2] + ["    ...", "}"]).join("\n")
			else
				(lines[0,SUMMARY_LINES-1] + ["    ..."]).join("\n")
			end
		end
	end

	class Document < Array
	end

	class Include
		def initialize(path)
			@path = path
		end
		attr_reader :path

		def text
			"include #{@path}"
		end
	end


	class Namespace < Element
		def initialize(scopes, lang=nil)
			@scopes = scopes
			@lang = lang
		end
		attr_reader :scopes, :lang

		def text
			if @lang
				"namespace #{@lang} #{@scopes.join('.')}"
			else
				"namespace #{@scopes.join('.')}"
			end
		end
	end


	class Message < Element
		def initialize(name, super_class, fields)
			@name = name
			@super_class = super_class
			@fields = fields
		end
		attr_reader :name, :super_class, :fields

		def text
			t = "message #{@name}"
			t << " < #{@super_class.text}" if @super_class
			t << " {\n"
			t << @fields.map {|f| "    #{f.text}\n" }.join
			t << "}"
			t
		end
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

		def text
			if @modifier == FIELD_OPTIONAL
				"#{@id}: optional #{@type.text} #{@name}"
			else
				"#{@id}: #{@type.text} #{@name}"
			end
		end
	end

	class ValueAssignedField < Field
		def initialize(id, type, modifier, name, value)
			super(id, type, modifier, name)
			@value = value
		end
		attr_reader :value

		def text
			"#{super} = #{@value.text}"
		end
	end


	class Enum < Element
		def initialize(name, fields)
			@name = name
			@fields = fields
		end
		attr_reader :name, :fields

		def text
			t = "enum #{@name} {\n"
			t << @fields.map {|f| "    #{f.text}\n" }.join
			t << "}"
			t
		end
	end

	class EnumField < Element
		def initialize(id, name)
			@id = id
			@name = name
		end
		attr_reader :id, :name

		def text
			"#{@id}: #{@name}"
		end
	end


	class Service < Element
		def initialize(name, version, functions)
			@name = name
			@version = version
			@functions = functions
		end
		attr_reader :name, :version, :functions

		def text
			t = "service #{@name}"
			t << ":#{@version}" if @version
			t << " {\n"
			t << @functions.map {|f| "    #{f.text}\n" }.join
			t << "}"
			t
		end
	end

	class Inherit < Element
	end

	class InheritAll < Inherit
		def text
			"inherit *"
		end
	end

	class InheritName < Inherit
		def initialize(name)
			@name = name
		end
		attr_reader :name

		def text
			"inherit #{@name}"
		end
	end

	class InheritFunc < Inherit
		def initialize(name, return_type, args, exceptions)
			@name = name
			@return_type = return_type
			@args = args
			@exceptions = exceptions
		end
		attr_reader :name, :return_type, :args, :exceptions

		def text
			t = "inherit #{@return_type.text} #{@name}(#{@args.map {|a| a.text }.join(', ') })"
			t << " throws #{@exceptions.map {|ex| ex.text }.join(', ')}" if @exceptions && !@exceptions.empty?
			t
		end
	end

	class Func < Element
		def initialize(name, return_type, args, exceptions)
			@name = name
			@return_type = return_type
			@args = args
			@exceptions = exceptions
		end
		attr_reader :name, :return_type, :args, :exceptions

		def text
			t = "#{@return_type.text} #{@name}(#{@args.map {|a| a.text }.join(', ')})"
			t << " throws #{@exceptions.map {|ex| ex.text }.join(', ')}" if @exceptions && !@exceptions.empty?
			t
		end
	end


	class Application < Element
		def initialize(name, scopes)
			@name = name
			@scopes = scopes
		end

		attr_reader :name
		attr_reader :scopes

		def text
			t = "application #{@name} {\n"
			t << @scopes.map {|sc| "    #{sc.text}\n" }.join
			t << "}"
			t
		end
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

		def text
			t = "#{@service}:#{@version} #{@name}"
			t << " default" if @default
			t
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

		def text
			if @nullable
				"#{@name}?"
			else
				"#{@name}"
			end
		end
	end

	class GenericType < Type
		def initialize(name, type_params, nullable=false)
			super(name, nullable)
			@type_params = type_params
		end
		attr_reader :type_params

		def text
			"#{super}<#{@type_params.map {|tp| tp.text }.join(',')}>"
		end
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

		def text
			"#{@name}"
		end
	end

	class EnumLiteral < Literal
		def initialize(name, field)
			@name = name
			@field = field
		end
		attr_reader :name, :field

		def text
			"#{@name}.#{@field}"
		end
	end

	class IntLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value

		def text
			"#{@value}"
		end
	end

	class FlaotLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value

		def text
			"#{@value}"
		end
	end

	class NilLiteral < Literal
		def text
			%[nil]
		end
	end

	class BoolLiteral < Literal
		def initialize(value)
			@value = value
		end
		attr_reader :value

		def text
			"#{@value}"
		end
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

		def text
			@value.dump
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
