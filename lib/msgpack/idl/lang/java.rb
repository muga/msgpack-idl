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
		gen_messages
		gen_servers
		gen_clients
	end

	def gen_init
		@datadir = File.join(File.dirname(__FILE__), 'java')
		@pkgoutdir = File.join(@outdir, @ir.namespace)

		@engine = Tenjin::Engine.new(:cache => false)
	end

	def gen_messages
		ctx = Context.new(:package, :message, :name)
		ctx.package = @ir.namespace

		@ir.messages.each {|t|
			ctx.message = t
			ctx.name = t.name
			render('message.java', ctx, "#{ctx.name}")
		}
	end

	def gen_servers
		ctx = Context.new(:package, :service, :version, :functions, :name)
		ctx.package = @ir.namespace + ['server']

		@ir.services.each {|s|
			ctx.service = s
			s.versions.each {|v|
				ctx.version  = v.version
				ctx.functions = v.functions
				ctx.name = "#{s.name}_#{v.version}"
				render('server.java', ctx, "server/#{ctx.name}")
			}
		}
	end

	def gen_clients
		ctx = Context.new(:package, :service, :version, :functions, :name)
		ctx.package = @ir.namespace + ['client']

		@ir.services.each {|s|
			ctx.service = s
			s.versions.each {|v|
				ctx.version = v.version
				ctx.functions = v.functions
				ctx.name = "#{s.name}_#{v.version}"
				render('client.java', ctx, "client/#{ctx.name}")
			}
		}
	end

	private
	def render(template_fname, ctx, fname)
		template_path = File.join(@datadir, template_fname)
		code = @engine.render(template_path, ctx)
		path = File.join(@pkgoutdir, fname) + '.java'
		FileUtils.mkdir_p(File.dirname(path))
		File.open(path, "w") {|f|
			f.write(code)
		}
	end


	class Context
		include Tenjin::ContextHelper

		def initialize(*member)
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

		def format_package
			if package.empty?
				""
			else
				"package #{package.join('.')};"
			end
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

		TYPE_PARAMETER_REMAP = NULLABLE_REMAP

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
				name = PRIMITIVE_TYPEMAP[t.name] || name
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
			'float'   => '0.0',
			'double'  => '0',
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
				"#{to} = #{v.int};"
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
					return %[{
						#{to} = new #{format_type_impl(t)}();
						int n = #{pac}.unpackArray();
						#{format_type(e)} e;
						for(int i=0; i < n; i++) {
							#{format_unpack("e", pac, e)}
							#{to}.add(e);
						}
					}]
				elsif t.map_type?
					k = t.type_params[0]
					v = t.type_params[1]
					return %[{
						#{to} = new #{format_type_impl(t)}();
						int n = #{pac}.unpackMap();
						#{format_type(k)} k;
						#{format_type(v)} v;
						for(int i=0; i < n; i++) {
							#{format_unpack("k", pac, k)}
							#{format_unpack("v", pac, v)}
							#{to}.put(k, v);
						}
					}]
				end
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
					return %[{
						#{to} = new #{format_type_impl(t)}();
						#{format_type(e)} e;
						for(MessagePackObject o : #{obj}.asArray()) {
							#{format_convert("e", "o", e)}
							#{to}.add(e);
						}
					}]
				elsif t.map_type?
					k = t.type_params[0]
					v = t.type_params[1]
					return %[{
						#{to} = new #{format_type_impl(t)}();
						#{format_type(k)} k;
						#{format_type(v)} v;
						for(Map.EntrySet<MessagePackObject,MessagePackObject> kv : #{obj}.asMap().entrySet()) {
							#{format_convert("k", "kv.getKey()", k)}
							#{format_convert("v", "kv.getValue()", v)}
							#{to}.put(k, v);
						}
					}]
				end
			end
			method = PRIMITIVE_CONVERT[t.name] || "convert(new #{t.name}())"
			"#{to} = #{obj}.#{method};"
		end
	end
end


end
end
end
