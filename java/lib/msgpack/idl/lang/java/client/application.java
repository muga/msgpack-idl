#{format_package("client")}

import java.io.Closeable;
import org.msgpack.rpc.Session;
import org.msgpack.rpc.Client;

public class #{@name} implements Closeable {
	private Session session;

	public #{@name}(Session session) {
		this.session = session;
	}

	public void close() {
		if(session instanceof Client) {
			((Client)session).close();
		}
	}

	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		public #{s.name}_#{c.version} #{c.name}() {
			return new #{s.name}_#{c.version}(this.session, "#{c.name}");
		}
		<?rb s.versions_upto(c.version-1) {|sv| ?>
		public #{s.name}_#{sv.version} #{c.name}_#{sv.version}() {
			return #{c.name}().version#{sv.version}();
		}
		<?rb } ?>
		public #{s.name}_#{c.version} #{c.name}_#{c.version}() {
			return #{c.name}();
		}
	<?rb } ?>
}

