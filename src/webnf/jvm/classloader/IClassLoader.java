package webnf.jvm.classloader;

import java.io.IOException;
import java.net.URL;
import java.util.Enumeration;

public interface IClassLoader {

	Class<?> findClass(String name) throws ClassNotFoundException;
	Enumeration<URL> findResources(String name) throws IOException;

}
