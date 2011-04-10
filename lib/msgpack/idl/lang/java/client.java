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

public abstract class #{@name} {
	<?rb @functions.each {|f| ?>
	public #{format_type(f.return_type)} #{f.name}(#{ f.args.map {|arg| format_type(arg.type) +" "+ arg.name }.join(', ') });
	<?rb } ?>

	// TODO
}

