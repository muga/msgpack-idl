#{format_package("client")}

import org.msgpack.rpc.Session;

public class #{@name} implements Closeable {
	private Session s;

	public #{@name}(Session s) {
		this.s = s;
	}

	<?rb @scopes.each {|c| ?>
		<?rb s = c.service ?>
		public #{s.name}_#{c.version} #{c.name}() {
			return new #{s.name}_#{c.version}(this.s, "#{c.name}");
		}
		<?rb s.versions_upto(c.version-1) {|sv| ?>
		public #{s.name}_#{sv.version} #{c.name}_#{sv.version}() {
			return #{c.name}().version#{sv.version}();
		}
		public #{s.name}_#{c.version} #{c.name}_#{c.version}() {
			return #{c.name}();
		}
		<?rb } ?>
	<?rb } ?>
}

