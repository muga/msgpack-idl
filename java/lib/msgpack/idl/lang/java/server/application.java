#{format_package("server")}

import java.util.Map;
import java.util.HashMap;
import java.io.IOException;
import org.msgpack.MessageTypeException;
import org.msgpack.rpc.dispatcher.Dispatcher;
import org.msgpack.rpc.Request;

public class #{@name} implements Dispatcher {
	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		<?rb s.versions_upto(c.version) {|sv| ?>
			private #{s.name}_#{sv.version} #{c.name}_#{sv.version};
		<?rb } ?>
	<?rb } ?>

	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		<?rb s.versions_upto(c.version) {|sv| ?>
			public #{s.name}_#{sv.version} #{c.name}_#{sv.version}() {
				return this.#{c.name}_#{sv.version};
			}
		<?rb } ?>
	<?rb } ?>

	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		<?rb s.versions_upto(c.version) {|sv| ?>
			<?rb sv.functions.each {|f| ?>
				private class Default_#{s.name}_#{sv.version}_#{f.name} implements #{s.name}_#{sv.version}.I#{f.name} {
					public #{format_type(f.return_type)} #{f.name}(#{format_message_class(s, sv.version)}.A#{f.name} args) {
						<?rb if f.inherited? ?>
							<?rb if f.return_type.void_type? ?>
								#{@name}.this.#{c.name}_#{f.inherit_version}.get#{f.name.capitalize}().#{f.name}(args);
							<?rb else ?>
								return #{@name}.this.#{c.name}_#{f.inherit_version}.get#{f.name.capitalize}().#{f.name}(args);
							<?rb end ?>
						<?rb else ?>
							throw new RPCError(".NotImplemented");  // TODO
						<?rb end ?>
					}
				}
			<?rb } ?>
		<?rb } ?>
	<?rb } ?>

	private HashMap<String, Dispatcher> scopeDispatchTable;

	public #{@name}() {
		this.scopeDispatchTable = new HashMap<String, Dispatcher>();
	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		<?rb s.versions_upto(c.version) {|sv| ?>
			this.scopeDispatchTable.put("#{c.name}:#{sv.version}", this.#{c.name}_#{sv.version});
		<?rb } ?>
		this.scopeDispatchTable.put("#{c.name}", this.#{c.name}_#{c.version});
	<?rb } ?>

	this.scopeDispatchTable.put("", this.#{@default_scope.name}_#{@default_scope.version});
	<?rb @default_scope.service.versions_upto(@default_scope.version) {|sv| ?>
	this.scopeDispatchTable.put("#{sv.version}", this.#{@default_scope.name}_#{sv.version});
	<?rb } ?>

	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		<?rb s.versions_upto(c.version) {|sv| ?>

			<?rb sv.functions.each {|f| ?>
				this.#{c.name}_#{sv.version}.set#{f.name.capitalize}(new Default_#{s.name}_#{sv.version}_#{f.name}());
			<?rb } ?>

		<?rb } ?>
	<?rb } ?>
	}

	public void dispatch(Request request) throws Exception {
		String methodName = request.getMethodName();
		int ic = methodName.indexOf(':');
		if(ic < 0) {
			this.#{@default_scope.name}_#{@default_scope.version}.dispatch(methodName, request);
			return;
		}

		String scope = methodName.substring(ic+1);
		methodName = methodName.substring(0, ic);
		Dispatcher dp = this.scopeDispatchTable.get(scope);
		if(dp == null) {
			throw new MessageTypeException("FIXME");
		}

		dp.dispatch(methodName, request);
	}
}

