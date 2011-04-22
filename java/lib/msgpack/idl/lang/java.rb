#
# MessagePack IDL Generator for Java
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
module Lang

require 'fileutils'
require 'tenjin'

class JavaGenerator < GeneratorModule
	Generator.register('java', self)

	def initialize(ir, outdir)
		@ir = ir
		@outdir = outdir
	end

	def generate!
		gen_init
		gen_enums
		gen_messages
		gen_services
		gen_server_services
		gen_server_applications
		gen_client_services
		gen_client_applications
	end

	def gen_init
		@datadir = File.join(File.dirname(__FILE__), 'java')
		@pkgoutdir = File.join(@outdir, @ir.namespace)

		@engine = Tenjin::Engine.new(:cache => false)
	end

	def gen_enums
		ctx = Context.new(self, :namespace, :enum, :fields, :name)
		ctx.namespace = @ir.namespace

		@ir.enums.each {|t|
			ctx.enum = t
			ctx.name = t.name
			ctx.fields = t.fields
			render_file('enum.java', ctx, "#{ctx.name}")
		}
	end

	def gen_messages
		ctx = Context.new(self, :namespace, :message, :super_class, :name)
		ctx.namespace = @ir.namespace

		@ir.messages.each {|t|
			ctx.message = t
			if t.super_class
				ctx.super_class = t.super_class.name
			end
			ctx.name = t.name
			render_file('message.java', ctx, "#{ctx.name}")
		}
	end

	def gen_services
		ctx = Context.new(self, :namespace, :service, :version, :functions, :name)
		ctx.namespace = @ir.namespace

		@ir.services.each {|s|
			ctx.service = s
			s.versions.each {|v|
				ctx.version  = v.version
				ctx.functions = v.functions
				ctx.name = "#{s.name}_#{v.version}"
				render_file('service_version.java', ctx, "#{ctx.name}")
			}
		}
	end

	def gen_server_services
		ctx = Context.new(self, :namespace, :service, :version, :functions, :name, :message_class)
		ctx.namespace = @ir.namespace

		@ir.services.each {|s|
			ctx.service = s
			s.versions.each {|v|
				ctx.version  = v.version
				ctx.functions = v.functions
				ctx.name = "#{s.name}_#{v.version}"
				ctx.message_class = (@ir.namespace + ["#{s.name}_#{v.version}"]).join('.')
				render_file('server/service_version.java', ctx, "server/#{ctx.name}")
			}
		}
	end

	def gen_server_applications
		ctx = Context.new(self, :namespace, :name, :scopes, :default_scope)
		ctx.namespace = @ir.namespace

		service_apps = @ir.services.map {|s|
			scopes = [IR::Scope.new("", s, s.versions.last.version, true)]
			IR::Application.new(s.name, scopes)
		}

		(@ir.applications + service_apps).each {|app|
			ctx.name = app.name
			ctx.scopes = app.scopes
			ctx.default_scope = app.default_scope
			render_file('server/application.java', ctx, "server/#{ctx.name}")
		}
	end

	def gen_client_services
		ctx = Context.new(self, :namespace, :service, :version, :functions, :name, :message_class)
		ctx.namespace = @ir.namespace

		@ir.services.each {|s|
			ctx.service = s
			s.versions.each {|v|
				ctx.version = v.version
				ctx.functions = v.functions
				ctx.name = "#{s.name}_#{v.version}"
				ctx.message_class = (@ir.namespace + ["#{s.name}_#{v.version}"]).join('.')
				render_file('client/service_version.java', ctx, "client/#{ctx.name}")
			}
			v = s.versions.last
			ctx.version = nil
			ctx.functions = v.functions
			ctx.name = "#{s.name}"
			ctx.message_class = (@ir.namespace + ["#{s.name}_#{v.version}"]).join('.')
			render_file('client/service_version.java', ctx, "client/#{ctx.name}")
		}
	end

	def gen_client_applications
		ctx = Context.new(self, :namespace, :name, :scopes, :default_scope)
		ctx.namespace = @ir.namespace

		@ir.applications.each {|app|
			ctx.name = app.name
			ctx.scopes = app.scopes
			ctx.default_scope = app.default_scope
			render_file('client/application.java', ctx, "client/#{ctx.name}")
		}
	end

	def render(template_fname, ctx)
		template_path = File.join(@datadir, template_fname)
		@engine.render(template_path, ctx)
	end

	def render_file(template_fname, ctx, fname)
		code = render(template_fname, ctx)
		path = File.join(@pkgoutdir, fname) + '.java'
		FileUtils.mkdir_p(File.dirname(path))
		File.open(path, "w") {|f|
			f.write(code)
		}
	end

	def format_message(t, name = t.name)
		ctx = Context.new(self, :message, :super_class, :name)
		ctx.message = t
		if t.super_class
			ctx.super_class = t.super_class.name
		elsif t.is_a?(IR::Exception)
			ctx.super_class = "RemoteError"
		end
		ctx.name = name
		render('message_body.java', ctx)
	end


	class Context
		include Tenjin::ContextHelper

		def initialize(gen, *member)
			@gen = gen

			(class << self; self; end).module_eval {
				member.each {|m|
					define_method("#{m}") {
						instance_variable_get("@#{m}")
					}
					define_method("#{m}=") {|v|
						instance_variable_set("@#{m}", v)
					}
				}
			}
		end

		def format_package(*extra)
			name = format_package_name(*extra)
			if name.empty?
				""
			else
				"package #{name};"
			end
		end

		def format_package_name(*extra)
			package = namespace + extra
			package.join('.')
		end

		PRIMITIVE_TYPEMAP = {
			'void'   => 'void',
			'byte'   => 'byte',
			'short'  => 'short',
			'int'    => 'int',
			'long'   => 'long',
			'ubyte'  => 'short',
			'ushort' => 'int',
			'uint'   => 'long',
			'ulong'  => 'BigInteger',
			'float'  => 'float',
			'double' => 'double',
			'bool'   => 'boolean',
			'raw'    => 'byte[]',
			'string' => 'String',
			'list'   => 'List',
			'map'    => 'Map',
		}

		NULLABLE_REMAP = {
			'byte'    => 'Byte',
			'short'   => 'Short',
			'int'     => 'Integer',
			'long'    => 'Long',
			'float'   => 'Float',
			'double'  => 'Double',
			'boolean' => 'Boolean',
		}

		TYPE_PARAMETER_REMAP = NULLABLE_REMAP.merge({
			:void     => 'Void',
		})

		IFACE_CLASS_REMAP = {
			'Map'     => 'HashMap',
			'List'    => 'ArrayList',
		}

		def format_nullable_type(t)
			if t.nullable_type?
				real_type = t.real_type
				name = PRIMITIVE_TYPEMAP[real_type.name] || real_type.name
				name = NULLABLE_REMAP[name] || name
				return real_type, name
			else
				name = PRIMITIVE_TYPEMAP[t.name] || t.name
				return t, name
			end
		end

		def format_parameterized_type(t, name)
			if t.parameterized_type?
				name + '<' +
					t.type_params.map {|tp|
						n = format_type(tp)
						TYPE_PARAMETER_REMAP[n] || n
					}.join(', ') + '>'
			else
				name
			end
		end

		def format_type(t)
			t, name = format_nullable_type(t)
			format_parameterized_type(t, name)
		end

		def format_message(t, name = t.name)
			@gen.format_message(t, name)
		end

		def format_type_parameter(t)
			t, name = format_nullable_type(t)
			name = TYPE_PARAMETER_REMAP[name] || name
			format_parameterized_type(t, name)
		end

		def format_type_impl(t)
			t, name = format_nullable_type(t)
			name = IFACE_CLASS_REMAP[name] || name
			format_parameterized_type(t, name)
		end

		PRIMITIVE_DEFAULT = {
			'byte'    => '0',
			'short'   => '0',
			'int'     => '0',
			'long'    => '0',
			'float'   => '0.0f',
			'double'  => '0.0',
			'boolean' => 'false',
			'byte[]'  => 'new byte[0]',
			'String'  => '""',
		}

		def format_initial_value(to, f)
			v = f.value
			case v
			when IR::NilValue
				"#{to} = null;"

			when IR::IntValue
				tt, name = format_nullable_type(f.type)
				if name == "BigInteger"
					"#{to} = BigInteger.valueOf(#{v.int}L);"
				elsif name == "long"
					"#{to} = #{v.int}L;"
				else
					"#{to} = #{v.int};"
				end

			when IR::BoolValue
				if v.bool
					"#{to} = true;"
				else
					"#{to} = false;"
				end

			when IR::EnumValue
				"#{to} = #{v.enum.name}.#{v.field.name};"
			when IR::EmptyValue
				tt, name = format_nullable_type(f.type)
				v = PRIMITIVE_DEFAULT[name]
				v ||= "new #{format_type_impl(f.type)}()"
				"#{to} = #{v};"
			else
				raise SemanticsError, "unknown initial value type: #{v.class}"
			end
		end

		PRIMITIVE_UNPACK = {
			'byte'   => 'unpackByte()',
			'short'  => 'unpackShort()',
			'int'    => 'unpackInt()',
			'long'   => 'unpackLong()',
			'ubyte'  => 'unpackShort()',
			'ushort' => 'unpackInt()',
			'uint'   => 'unpackLong()',
			'ulong'  => 'unpackBigInteger()',
			'float'  => 'unpackFloat()',
			'double' => 'unpackDouble()',
			'bool'   => 'unpackBoolean()',
			'raw'    => 'unpackByteArray()',
			'string' => 'unpackString()',
		}

		def format_unpack(to, pac, t)
			if t.parameterized_type?
				if t.list_type?
					e = t.type_params[0]
					anon_id = next_anon_id
					vn = "n#{anon_id}"
					ve = "e#{anon_id}"
					vi = "i#{anon_id}"
					return %[{
						#{to} = new #{format_type_impl(t)}();
						int #{vn} = #{pac}.unpackArray();
						#{format_type(e)} #{ve};
						for(int #{vi}=0; #{vi} < #{vn}; #{vi}++) {
							#{format_unpack("#{ve}", pac, e)}
							#{to}.add(#{ve});
						}
					}]
				elsif t.map_type?
					anon_id = next_anon_id
					k = t.type_params[0]
					v = t.type_params[1]
					vn = "n#{anon_id}"
					vk = "k#{anon_id}"
					vv = "v#{anon_id}"
					vi = "i#{anon_id}"
					return %[{
						#{to} = new #{format_type_impl(t)}();
						int #{vn} = #{pac}.unpackMap();
						#{format_type(k)} #{vk};
						#{format_type(v)} #{vv};
						for(int #{vi}=0; #{vi} < #{vn}; #{vi}++) {
							#{format_unpack("#{vk}", pac, k)}
							#{format_unpack("#{vv}", pac, v)}
							#{to}.put(#{vk}, #{vv});
						}
					}]
				end

			elsif t.is_a?(IR::Message)
				return %[#{to} = new #{t.name}();
					#{to}.messageUnpack(#{pac});]

			elsif t.is_a?(IR::Enum)
				return "#{to} = #{t.name}.enumOf(#{pac}.unpackInt());"
			end

			method = PRIMITIVE_UNPACK[t.name] || "unpack(#{t.name}.class)"
			"#{to} = #{pac}.#{method};"
		end

		PRIMITIVE_CONVERT = {
			'byte'   => 'asByte()',
			'short'  => 'asShort()',
			'int'    => 'asInt()',
			'long'   => 'asLong()',
			'ubyte'  => 'asShort()',
			'ushort' => 'asInt()',
			'uint'   => 'asLong()',
			'ulong'  => 'asBigInteger()',
			'float'  => 'asFloat()',
			'double' => 'asDouble()',
			'bool'   => 'asBoolean()',
			'raw'    => 'asByteArray()',
			'string' => 'asString()',
		}

		def format_convert(to, obj, t)
			if t.parameterized_type?
				if t.list_type?
					e = t.type_params[0]
					anon_id = next_anon_id
					ve = "e#{anon_id}"
					vo = "o#{anon_id}"
					return %[{
						#{to} = new #{format_type_impl(t)}();
						#{format_type(e)} #{ve};
						for(MessagePackObject #{vo} : #{obj}.asArray()) {
							#{format_convert("#{ve}", "#{vo}", e)}
							#{to}.add(#{ve});
						}
					}]
				elsif t.map_type?
					k = t.type_params[0]
					v = t.type_params[1]
					anon_id = next_anon_id
					vk = "k#{anon_id}"
					vv = "v#{anon_id}"
					vkv = "kv#{anon_id}"
					return %[{
						#{to} = new #{format_type_impl(t)}();
						#{format_type(k)} #{vk};
						#{format_type(v)} #{vv};
						for(Map.Entry<MessagePackObject,MessagePackObject> #{vkv} : #{obj}.asMap().entrySet()) {
							#{format_convert("#{vk}", "#{vkv}.getKey()", k)}
							#{format_convert("#{vv}", "#{vkv}.getValue()", v)}
							#{to}.put(#{vk}, #{vv});
						}
					}]
				end

			elsif t.is_a?(IR::Message)
				return %[#{to} = new #{t.name}();
					#{to}.messageConvert(#{obj});]

			elsif t.is_a?(IR::Enum)
				return "#{to} = #{t.name}.enumOf(#{obj}.asInt());"
			end

			method = PRIMITIVE_CONVERT[t.name] || "convert(new #{t.name}())"
			"#{to} = #{obj}.#{method};"
		end

		def next_anon_id
			@anon_id ||= -1
			@anon_id += 1
		end

		def format_message_class(s, version)
			(namespace + ["#{s.name}_#{version}"]).join('.')
		end
	end
end


end
end
end
