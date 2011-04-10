#{@package}

import java.util.List;
import java.util.Set;
import java.util.Map;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.HashMap;
import java.io.IOException;
import org.msgpack.MessageTypeException;

public class #{@name} {
	<?rb @functions.each {|f| ?>
	public interface I#{f.name} {
		#{format_type(f.return_type)} #{f.name}(#{ f.args.map {|arg| format_type(arg.type) +" "+ arg.name }.join(', ') });
	}
	<?rb } ?>

	<?rb @functions.each {|f| ?>
	public void set#{f.name.capitalize}(I#{f.name} #{f.name}) {
		this.#{f.name} = f.name;
	}
	<?rb } ?>

	public void set(Object o) {
		<?rb @functions.each {|f| ?>
		if(o instanceof I#{f.name}) {
			this.set#{f.name.capitalize}((I#{f.name})o);
		}
		<?rb } ?>
	}

	<?rb @functions.each {|f| ?>
	private I#{f.name} #{f.name};
	<?rb } ?>

	// TODO
}

