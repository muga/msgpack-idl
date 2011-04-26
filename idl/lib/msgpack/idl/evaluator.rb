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

	class InheritAllMark
		def initialize(ast)
			@ast = ast
		end
		attr_reader :ast
		def name
			""
		end
	end

	class InheritMark
		def initialize(ast, name)
			@ast = ast
			@name = name
		end
		attr_reader :ast, :name
	end

	class InheritMarkWithCheck < InheritMark
		def initialize(ast, func)
			super(ast, func.name)
			@func = func
		end
		attr_reader :func
	end

	def initialize
		@names = {}  # name:String => AST::Element

		@types = {}  # name:String => AST::Type
		@generic_types = []  # Template

		@global_namespace = IR::Namespace.new([])
		@lang_namespace = {}     # lang:String => scope:Namespace

		@service_versions = {} # serviceName:String => (IR::Service, [(IR::ServiceVersion, AST::ServiceVersion)])

		init_built_in

		@ir_types = []
		@ir_services = []
		@ir_applications = []
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
					raise InvalidNameError, "Super class of the exception `#{e.super_class}' must be an exception"
				end
			end
			new_fields = resolve_fields(e.fields, super_message)
			add_exception(e.name, super_message, new_fields)

		when AST::Message
			check_name(e.name, e)
			if e.super_class
				super_message = resolve_type(e.super_class)
				if !super_message.is_a?(IR::Message)
					raise InvalidNameError, "Super class of the message `#{e.super_class}' must be a message"
				end
			end
			new_fields = resolve_fields(e.fields, super_message)
			add_message(e.name, super_message, new_fields)

		when AST::Enum
			check_name(e.name, e)
			fields = resolve_enum_fields(e.fields)
			add_enum(e.name, fields)

		when AST::Service
			v = e.version || 0
			check_service_version(e.name, v)
			funcs = resolve_service_partial(e.functions)
			add_service_version(e, e.name, v, funcs)

		when AST::Application
			check_name(e.name, e)
			scopes = resolve_scopes(e.scopes)
			add_application(e.name, scopes)

		else
			raise SemanticsError, "Unknown toplevel AST element `#{e.class}'"
		end

	rescue => error
		raise_error(error, e)
	end

	def evaluate_inheritance
		@ir_services = @service_versions.values.map {|s,versions|
			versions = versions.sort_by {|sv,ast| sv.version }

			super_versions = []
			versions.each do |sv,ast|
				begin
					real_functions = []
					sv.functions.each {|f|
						case f
						when InheritAllMark
							begin
								if super_versions.empty?
									raise InheritanceError, "Inherit on the oldest version is invalid"
								end
								last = super_versions.last
								last.functions.each {|ifunc|
									real_functions << IR::InheritedFunction.new(last.version, ifunc)
								}
							rescue => error
								raise_error(error, f.ast)
							end

						when InheritMark
							begin
								if super_versions.empty?
									raise InheritanceError, "Inherit on the oldest version is invalid"
								end
								inherit_func = nil
								inherit_version = nil
								super_versions.reverse_each do |ssv|
									inherit_func = ssv.functions.find {|ifunc| f.name == ifunc.name }
									if inherit_func
										inherit_version = ssv.version
										break
									end
								end

								unless inherit_func
									raise InheritanceError, "No such function: #{f.name}"
								end

								if f.is_a?(InheritMarkWithCheck)
									if inherit_func.args != f.func.args ||
											inherit_func.return_type != f.func.return_type ||
											inherit_func.exceptions != f.func.exceptions
										raise InheritanceError, "Function signature is mismatched with #{s.name}:#{inherit_version}.#{f.name}"
									end
								end

								real_functions << IR::InheritedFunction.new(inherit_version, inherit_func)
							rescue => error
								raise_error(error, f.ast)
							end

						when IR::Function
							real_functions << f

						else
							raise "Unknown partially evaluated function: #{f.inspect}"
						end
					}

					if real_functions.uniq!
						# may be caused by InheritAllMark
						# FIXME show warning?
					end

					sv.functions = real_functions

					super_versions << sv
				rescue => error
					raise_error(error, ast)
				end
			end
			s.versions = super_versions

			s
		}

		self
	end

	def evaluate_spec(lang)
		lang = lang.to_s
		ns = spec_namespace(lang)
		types = spec_types(lang)
		services = spec_services(lang)
		applications = spec_applications(lang)
		IR::Spec.new(ns, types, services, applications)
	end

	private
	def raise_error(error, ast = nil)
		if ast
			msg = %[#{error.message}

while processing:
#{ast.summary.split("\n").map {|l| "  #{l}" }.join("\n")}]

		else
			msg = error.message
		end

		wrap = error.class.new(msg)
		wrap.set_backtrace(error.backtrace)
		raise wrap
	end

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

	def spec_applications(lang)
		@ir_applications
	end

	def check_name(name, e)
		if ee = @names[name]
			raise DuplicatedNameError, "Duplicated name `#{name}'"
		end
		@names[name] = e
	end


	def resolve_simple_type(e)
		type = @types[e.name]
		unless type
			raise NameNotFoundError, "Type not found `#{e.name}'"
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
			raise NameNotFoundError, "Generic type not matched `#{e.name}'"
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
		super_used_names = {}
		super_used_ids = []

		if super_message
			super_message.all_fields.each {|f|
				super_used_ids[f.id] = true
				super_used_names[f.name] = true
			}
		end

		new_fields = fields.map {|e|
			begin
				if e.id == 0
					raise InvalidNameError, "Field id 0 is invalid"
				end
				if e.id < 0
					raise InvalidNameError, "Field id < 0 is invalid"
				end
				if n = used_ids[e.id]
					raise DuplicatedNameError, "Field id #{e.id} is duplicated with field `#{n}'"
				end
				if i = used_names[e.name]
					raise DuplicatedNameError, "Field name `#{e.name}' is duplicated with id #{i}"
				end
				if super_used_ids[e.id]
					raise InheritanceError, "Field id #{e.id} is duplicated with super class `#{e.name}'"
				end
				if super_used_names[e.name]
					raise InheritanceError, "Field name is duplicated with super class `#{e.name}'"
				end

				used_ids[e.id] = e.name
				used_names[e.name] = e.id

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
			rescue => error
				raise_error(error, e)
			end
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
		if e.is_a?(AST::ConstLiteral)
			e = BUILT_IN_LITERAL[e.name] || e
		end
		v = case e
		when AST::NilLiteral
			IR::NilValue.nil

		when AST::TrueLiteral
			IR::BoolValue.true

		when AST::FalseLiteral
			IR::BoolValue.false

		when AST::IntLiteral
			IR::IntValue.new(e.value)

		when AST::EnumLiteral
			enum = resolve_type(e.name)
			if !enum.is_a?(IR::Enum)
				raise NameNotFoundError, "Not a enum type `#{e.name}'"
			end
			f = enum.fields.find {|f|
				f.name == e.field
			}
			if !f
				raise NameNotFoundError, "No such field at enum `#{e.name}': #{e.field}"
			end
			IR::EnumValue.new(enum, f)

		when AST::ConstLiteral
			raise NameNotFoundError, "Unknown constant `#{name}'"

		else
			raise SemanticsError, "unknown literal type: #{e.class}"
		end

		check_assignable(type, v)
		v
	end

	def check_assignable(type, v)
		if type.nullable_type? && v != IR::NilValue.nil
			raise TypeError, "Non-null value for nullable type is not allowed"
		end

		case v
		when IR::NilValue
			unless type.nullable_type?
				raise TypeError, "Assigning null to non-nullable field"
			end

		when IR::IntValue
			unless IR::Primitive::INT_TYPES.include?(type)
				raise TypeError, "Integer type is expected: #{type}"
			end
			# TODO overflow

		when IR::BoolValue
			if type != IR::Primitive::bool
				raise TypeError, "Bool type is expected: #{type}"
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
				raise TypeError, "Empty enum is not allowed: enum #{t.name}"
			end
			IR::EnumValue.new(t, t.fields.first)

		else
			IR::EmptyValue.new
		end
	end

	def resolve_enum_fields(fields)
		used_ids = []
		used_names = {}

		fields = fields.map {|e|
			begin
				if e.id < 0
					raise InvalidNameError, "Enum id < 0 is invalid"
				end
				if n = used_ids[e.id]
					raise DuplicatedNameError, "Enum field id #{e.id} is duplicated with `#{n}'"
				end
				if i = used_names[e.name]
					raise DuplicatedNameError, "Enum field name `#{e.name}' is duplicated with id #{i}"
				end

				used_ids[e.id] = e.name
				used_names[e.name] = e.id

				IR::EnumField.new(e.id, e.name)
			rescue => error
				raise_error(error, e)
			end
		}.sort_by {|f|
			f.id
		}

		return fields
	end

	def check_service_version(name, version)
		s, versions = @service_versions[name]
		if s
			versions.each {|sv,ast|
				if sv.version == version
					raise DuplicatedNameError, "Duplicated version #{version}"
				end
			}
		else
			check_name(name, nil)
		end
		nil
	end

	def resolve_service_partial(funcs)
		used_names = {}

		funcs = funcs.map {|e|
			case e
			when AST::InheritAll
				InheritAllMark.new(e)

			when AST::InheritName, AST::InheritFunc
				if used_names[e.name]
					raise DuplicatedNameError, "Duplicated function name `#{e.name}'"
				end
				used_names[e.name] = true

				if e.is_a?(AST::InheritFunc)
					func = resolve_func(e)
					InheritMarkWithCheck.new(e, func)
				else
					InheritMark.new(e, e.name)
				end

			when AST::Func
				if used_names[e.name]
					raise DuplicatedNameError, "Duplicated function name `#{e.name}'"
				end
				used_names[e.name] = true

				resolve_func(e)

			else
				raise SemanticsError, "Unknown service body AST element `#{e.class}': #{e.inspect}"
			end

		}.sort_by {|f|
			f.name
		}

		return funcs
	end

	def resolve_func(e)
		args = resolve_args(e.args)

		if e.return_type.name == "void"
			return_type = IR::Primitive.void
		else
			return_type = resolve_type(e.return_type)
		end

		exceptions = resolve_exceptions(e.exceptions)

		IR::Function.new(e.name, return_type, args, exceptions)

	rescue => error
		raise_error(error, e)
	end

	def resolve_args(args)
		used_ids = []
		used_names = {}

		args = args.map {|e|
			begin
				if e.id == 0
					raise InvalidNameError, "Argument id 0 is invalid"
				end
				if e.id < 0
					raise InvalidNameError, "Argument id < 0 is invalid"
				end
				if n = used_ids[e.id]
					raise DuplicatedNameError, "Argument id #{e.id} is duplicated with `#{n}'"
				end
				if i = used_names[e.name]
					raise DuplicatedNameError, "Argument name `#{e.name}' is duplicated with id #{i}"
				end

				used_ids[e.id] = e.name
				used_names[e.name] = e.id

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
			rescue => error
				raise_error(error, e)
			end
		}.sort_by {|a|
			a.id
		}

		return args
	end

	def resolve_exceptions(exceptions)
		# TODO
		[]
	end

	def resolve_scopes(scopes)
		ds = scopes.find_all {|e|
			e.default?
		}
		if ds.size > 1
			raise DuplicatedNameError, "Multiple default scope: #{ds.map {|e| e.name}.join(', ')}"
		end

		if	ds.empty?
			default_scope = scopes.first.name
		else
			default_scope = ds.first.name
		end

		used_names = {}

		scopes = scopes.map {|e|
			if used_names[e.name]
				raise DuplicatedNameError, "Duplicated scope name: #{e.name}"
			end

			s, versions = @service_versions[e.service]
			unless s
				raise NameNotFoundError, "No such service: #{e.name}"
			end

			sv = versions.find {|sv,ast| sv.version == e.version }
			unless sv
				raise NameNotFoundError, "No such service version: #{e.service}:#{s.version}"
			end

			used_names[e.name] = true

			default = default_scope == e.name

			IR::Scope.new(e.name, s, e.version, default)
		}

		return scopes
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

	def add_service_version(e, name, version, funcs)
		sv = IR::ServiceVersion.new(version, funcs)
		s, versions = @service_versions[name]
		unless s
			s = IR::Service.new(name, nil)
			versions = []
			@service_versions[name] = [s, versions]
		end
		versions << [sv, e]
		sv
	end

	def add_application(name, scopes)
		app = IR::Application.new(name, scopes)
		@ir_applications << app
		app
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
