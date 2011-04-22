#{format_package("client")}

import java.io.IOException;
import java.io.Closeable;
import org.msgpack.MessageTypeException;
import org.msgpack.MessagePackObject;
import org.msgpack.rpc.Session;
import org.msgpack.rpc.Client;
import org.msgpack.rpc.error.RemoteError;
import static #{@message_class}.*;

public class #{@name} implements Closeable {
	private Session session;

	<?rb if @version ?>
	private String scope;
	private String suffix;

	public #{@name}(Session session) {
		this(session, null);
	}

	public #{@name}(Session session, String scope) {
		this.session = session;
		this.scope = scope;
		if(scope != null) {
			this.suffix = ":"+scope+":#{@version}";
		} else {
			this.suffix = ":#{@version}";
		}
	}

	<?rb @service.versions_upto(@version-1) {|sv| ?>
	public #{@service.name}_#{sv.version} version#{sv.version}() {
		return new #{@service.name}_#{sv.version}(this.session, this.scope);
	}
	<?rb } ?>

	private String scopedMethodName(String methodName) {
		return methodName + this.suffix;
	}

	<?rb else  # if @version ?>
	public #{@name}(Session session) {
		this.session = session;
	}

	private String scopedMethodName(String methodName) {
		return methodName;
	}
	<?rb end  # if @version ?>

	<?rb @functions.each {|f| ?>
	public #{format_type(f.return_type)} #{f.name}(A#{f.name} args) {
		<?rb if f.return_type.void_type? ?>
			session.callApply(scopedMethodName("#{f.name}"), args);
		<?rb else ?>
			MessagePackObject obj = session.callApply(scopedMethodName("#{f.name}"), args);
			#{format_type(f.return_type)} r;
			#{format_convert("r", "obj", f.return_type)}
			return r;
		<?rb end ?>
	}

	<?rb args = f.args ?>
	public #{format_type(f.return_type)} #{f.name}(#{ args.map {|arg| format_type(arg.type) +" "+ arg.name }.join(', ') }) {
		A#{f.name} args = new A#{f.name}(#{ args.map {|arg| arg.name }.join(', ') });
		<?rb if f.return_type.void_type? ?>
			this.#{f.name}(args);
		<?rb else ?>
			return this.#{f.name}(args);
		<?rb end ?>
	}

	<?rb if f.max_id != f.max_required_id && f.max_required_id > 0 ?>
	<?rb args = f.args[0, f.max_required_id] ?>
	public #{format_type(f.return_type)} #{f.name}(#{ args.map {|arg| format_type(arg.type) +" "+ arg.name }.join(', ') }) {
		A#{f.name} args = new A#{f.name}(#{ args.map {|arg| arg.name }.join(', ') });
		<?rb if f.return_type.void_type? ?>
			this.#{f.name}(args);
		<?rb else ?>
			return this.#{f.name}(args);
		<?rb end ?>
	}
	<?rb end ?>

	<?rb } ?>

	public void close() {
		if(session instanceof Client) {
			((Client)session).close();
		}
	}
}

