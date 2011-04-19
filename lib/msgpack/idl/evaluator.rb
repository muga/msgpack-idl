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


class Evaluator
	include ProcessorModule

	class Template
		def initialize(generic_type, nullable=false)
			@name = generic_type.name
			@params = generic_type.type_params
			@generic_type = generic_type
			@nullable = nullable
		end
		attr_reader :generic_type, :nullable

		def nullable?
			@nullable
		end

		def match_all(name, array)
			if @name != name
				return nil
			end
			if array.size != @params.size
				return nil
			end
			resolved_params = @params.zip(array).map {|a,b|
				if b.class == IR::TypeParameterSymbol
					return nil
				end
				if a.class != IR::TypeParameterSymbol && a != b
					return nil
				end
				b
			}
			resolved_params
		end
	end

	def initialize
		@names = {}  # name:String => AST::Element

		@types = {}  # name:String => AST::Type
		@generic_types = []  # Template
		@void_type = IR::PrimitiveType.new('void')

		@global_namespace = ""   # Namespace
		@lang_namespace = {}     # lang:String => scope:Namespace

		init_built_in

		@ir_types = []
		@ir_services = []
	end

	def evaluate(ast)
		ast.each {|e|
			evaluate_one(e)
		}
	end

	def evaluate_one(e)
		case e
		when AST::Namespace
			add_namespace(e)

		when AST::Exception
			check_name(e.name, e)
			if e.super_class
				super_message = resolve_type(e.super_class)
				if !super_message.is_a?(IR::Exception)
					raise InvalidNameError, "`#{e.super_class}' is not a #{IR::Exception} but a #{super_message.class}"
				end
			end
			new_fields = resolve_fields(e.fields, super_message)
			add_exception(e.name, super_message, new_fields)

		when AST::Message
			check_name(e.name, e)
			if e.super_class
				super_message = resolve_type(e.super_class)
				if !super_message.is_a?(IR::Message)
					raise InvalidNameError, "`#{e.super_class}' is not a #{IR::Message} but a #{super_message.class}"
				end
			end
			new_fields = resolve_fields(e.fields, super_message)
			add_message(e.name, super_message, new_fields)

		when AST::Enum
			check_name(e.name, e)
			fields = resolve_enum_fields(e.fields)
			add_enum(e.name, fields)

		when AST::Service
			check_name(e.name, e)
			versions = resolve_versions(e.name, e.versions)
			add_service(e.name, versions)

		when AST::Application
			check_name(e.name, e)

		else
			raise SemanticsError, "Unknown toplevel AST element `#{e.class}': #{e.inspect}"
		end
	end

	def evaluate_spec(lang)
		lang = lang.to_s
		ns = spec_namespace(lang)
		types = spec_types(lang)
		services = spec_services(lang)
		IR::Spec.new(ns, types, services)
	end

	private
	def spec_namespace(lang)
		if ns = @lang_namespace[lang]
			return ns
		else
			@global_namespace
		end
	end

	def spec_types(lang)
		@ir_types
	end

	def spec_services(lang)
		@ir_services
	end

	def check_name(name, e)
		if ee = @names[name]
			raise DuplicatedNameError, "duplicated name `#{name}': #{e.inspect}"
		end
		@names[name] = e
	end


	def resolve_simple_type(e)
		type = @types[e.name]
		unless type
			raise NameNotFoundError, "type not found: #{e.name}"
		end
		if e.nullable? && !type.is_a?(IR::NullableType)
			IR::NullableType.new(type)
		else
			type
		end
	end

	def resolve_generic_type(e)
		query = e.type_params.map {|v|
			resolve_type(v)
		}
		resolved_types = nil
		template = nil
		@generic_types.find {|tmpl|
			if resolved_types = tmpl.match_all(e.name, query)
				template = tmpl
				true
			end
		}
		unless resolved_types
			raise NameNotFoundError, "generic type not matched: #{e.name}"
		end
		type = IR::ParameterizedType.new(resolved_types, template.generic_type)
		if template.nullable || e.nullable?
			IR::NullableType.new(type)
		else
			type
		end
	end

	def resolve_type(e)
		if e.is_a?(AST::GenericType)
			resolve_generic_type(e)
		else
			resolve_simple_type(e)
		end
	end

	def resolve_fields(fields, super_message)
		used_ids = []
		used_names = {}
		super_max_id = 0

		if super_message
			super_max_id = super_message.max_id
			super_message.all_fields.each {|f|
				used_names[f] = true
			}
		end

		new_fields = fields.map {|e|
			if e.id == 0
				raise InvalidNameError, "field id 0 is invalid"
			end
			if e.id < 0
				raise InvalidNameError, "field id < 0 is invalid"
			end
			if n = used_ids[e.id]
				raise DuplicatedNameError, "duplicated field id #{e.id}: #{n}, #{e.name}"
			end
			if used_names[e.name]
				raise DuplicatedNameError, "duplicated field name: #{e.name}"
			end
			if e.id < super_max_id
				raise InheritanceError, "field id #{e.is} is smaller than max field id of the super class"
			end

			used_ids[e.id] = e.name
			used_names[e.name] = e.name

			type = resolve_type(e.type)
			if e.modifier == AST::FIELD_OPTIONAL
				option  = IR::FIELD_OPTIONAL
			else
				option  = IR::FIELD_REQUIRED
			end

			if e.is_a?(AST::ValueAssignedField)
				v = resolve_initial_value(type, e.value)
			else
				v = resolve_implicit_value(type)
			end

			IR::Field.new(e.id, type, e.name, option, v)
		}.sort_by {|f|
			f.id
		}

		return new_fields
	end

	BUILT_IN_LITERAL = {
		'BYTE_MAX'   => AST::IntLiteral.new((2**7)-1),
		'SHORT_MAX'  => AST::IntLiteral.new((2**15)-1),
		'INT_MAX'    => AST::IntLiteral.new((2**31)-1),
		'LONG_MAX'   => AST::IntLiteral.new((2**63)-1),
		'UBYTE_MAX'  => AST::IntLiteral.new((2**8)-1),
		'USHORT_MAX' => AST::IntLiteral.new((2**16)-1),
		'UINT_MAX'   => AST::IntLiteral.new((2**32)-1),
		'ULONG_MAX'  => AST::IntLiteral.new((2**64)-1),
		'BYTE_MIN'   => AST::IntLiteral.new(-(2**7)),
		'SHORT_MIN'  => AST::IntLiteral.new(-(2**15)),
		'INT_MIN'    => AST::IntLiteral.new(-(2**31)),
		'LONG_MIN'   => AST::IntLiteral.new(-(2**63)),
	}

	def resolve_initial_value(type, e)
		if e.is_a?(ConstLiteral)
			e = BUILT_IN_LITERAL[e.name] || e
		end
		v = case e
		when NilLiteral
			IR::NilValue.nil

		when TrueLiteral
			IR::BoolValue.true

		when FalseLiteral
			IR::BoolValue.false

		when IntLiteral
			IR::IntValue.new(e.value)

		when EnumLiteral
			enum = resolve_type(e.name)
			if !enum.is_a?(IR::Enum)
				raise NameNotFoundError, "not a enum type: #{e.name}"
			end
			f = enum.fields.find {|f|
				f.name == e.field
			}
			if !f
				raise NameNotFoundError, "no such field in enum `#{e.name}': #{e.field}"
			end
			IR::EnumValue.new(enum, f)

		when ConstLiteral
			raise NameNotFoundError, "unknown constant: #{name}"

		else
			raise SemanticsError, "Unknown literal type: #{e.class}"
		end

		check_assignable(type, v)
		v
	end

	def check_assignable(type, v)
		if type.nullable_type? && v != IR::NilValue.nil
			raise TypeError, "not-nullable value for nullable type is not allowed"
		end

		case v
		when IR::NilValue
			unless type.nullable_type?
				raise TypeError, "nullable is expected: #{type}"
			end

		when IR::IntValue
			unless IR::Primitive::INT_TYPES.include?(type)
				raise TypeError, "integer type is expected: #{type}"
			end
			# TODO overflow

		when IR::BoolValue
			if type != IR::Primitive::bool
				raise TypeError, "bool type is expected: #{type}"
			end

		end
	end

	def resolve_implicit_value(t)
		if t.nullable_type?
			return IR::NilValue.nil
		end

		if IR::Primitive::INT_TYPES.include?(t)
			IR::IntValue.new(0)

		elsif t == IR::Primitive.bool
			IR::BoolValue.false

		elsif t.is_a?(IR::Enum)
			if t.fields.empty?
				raise TypeError, "empty enum: #{t.name}"
			end
			t.fields.first

		else
			IR::EmptyValue.new
		end
	end

	def resolve_enum_fields(fields)
		used_ids = []
		used_names = {}

		fields = fields.map {|e|
			if e.id < 0
				raise InvalidNameError, "enum id < 0 is invalid"
			end
			if n = used_ids[e.id]
				raise DuplicatedNameError, "duplicated enum id #{e.id}: #{n}, #{e.name}"
			end
			if used_names[e.name]
				raise DuplicatedNameError, "duplicated field name: #{e.name}"
			end

			used_ids[e.id] = e.name
			used_names[e.name] = e.name

			IR::EnumField.new(e.id, e.name)
		}.sort_by {|f|
			f.id
		}

		return fields
	end

	def resolve_versions(service_name, versions)
		used = []

		versions = versions.map {|e|
			if used[e.version]
				raise DuplicatedNameError, "duplicated version #{e.version}"
			end

			used[e.version] = true

			funcs = resolve_funcs(e.funcs)
			IR::ServiceVersion.new(funcs, e.version)
		}.sort_by {|v|
			v.version
		}

		return versions
	end

	def resolve_funcs(funcs)
		used_names = {}

		funcs = funcs.map {|e|
			if used_names[e.name]
				raise DuplicatedNameError, "duplicated function name: #{e.name}"
			end

			used_names[e.name] = true

			args = resolve_args(e.args)
			if e.return_type.name == "void"
				return_type = @void_type
			else
				return_type = resolve_type(e.return_type)
			end

			IR::Function.new(e.name, return_type, args)
		}.sort_by {|f|
			f.name
		}

		return funcs
	end

	def resolve_args(args)
		used_ids = []
		used_names = {}

		args = args.map {|e|
			if e.id == 0
				raise InvalidNameError, "argument id 0 is invalid"
			end
			if e.id < 0
				raise InvalidNameError, "argument id < 0 is invalid"
			end
			if n = used_ids[e.id]
				raise DuplicatedNameError, "duplicated argument id #{e.id}: #{n}, #{e.name}"
			end
			if used_names[e.name]
				raise DuplicatedNameError, "duplicated argument name: #{e.name}"
			end

			used_ids[e.id] = e.name
			used_names[e.name] = e.name

			type = resolve_type(e.type)
			if e.modifier == AST::FIELD_OPTIONAL
				option  = IR::FIELD_OPTIONAL
			else
				option  = IR::FIELD_REQUIRED
			end

			if e.is_a?(AST::ValueAssignedField)
				v = resolve_initial_value(type, e.value)
			else
				v = resolve_implicit_value(type)
			end

			IR::Argument.new(e.id, type, e.name, option, v)
		}.sort_by {|a|
			a.id
		}

		return args
	end


	def add_namespace(e)
		if e.lang
			@lang_namespace[e.lang] = IR::Namespace.new(e.scopes)
		else
			@global_namespace = IR::Namespace.new(e.scopes)
		end
	end

	def add_message(name, super_message, fields)
		m = IR::Message.new(name, super_message, fields)
		@types[name] = m
		@ir_types << m
		m
	end

	def add_exception(name, super_message, fields)
		e = IR::Exception.new(name, super_message, fields)
		@types[name] = e
		@ir_types << e
		e
	end

	def add_enum(name, fields)
		e = IR::Enum.new(name, fields)
		@types[name] = e
		@ir_types << e
		e
	end

	def add_service(name, versions)
		s = IR::Service.new(name, versions)
		@ir_services << s
		s
	end


	def init_built_in
		%w[byte short int long ubyte ushort uint ulong float double bool raw string].each {|name|
			check_name(name, nil)
			@types[name] = IR::Primitive.send(name)
		}
		check_name('list', nil)
		@generic_types << Template.new(IR::Primitive.list)
		check_name('map', nil)
		@generic_types << Template.new(IR::Primitive.map)
		#check_name('nullable', nil)
		#@generic_types << Template.new(IR::Primitive.nullable)
	end
end


end
end
