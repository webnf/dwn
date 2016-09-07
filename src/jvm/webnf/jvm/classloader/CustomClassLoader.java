package webnf.jvm.classloader;

import java.io.IOException;
import java.net.URL;
import java.util.Enumeration;

import org.slf4j.LoggerFactory;

public class CustomClassLoader extends ClassLoader {

	public final IClassLoader implementation;

	public CustomClassLoader(IClassLoader impl) {
		super(null);
		this.implementation = impl;
	}

	@Override
	protected Class<?> findClass(String name) throws ClassNotFoundException {
		return implementation.findClass(name);
	}

	@Override
	public Enumeration<URL> getResources(String name) throws IOException {
		return implementation.findResources(name);
	}

	@Override
	public URL getResource(String name) {
		try {
			Enumeration<URL> res = getResources(name);
			if (res.hasMoreElements()) {
				return res.nextElement();
			} else {
				return null;
			}
		} catch (IOException e) {
			LoggerFactory.getLogger(getClass()).error("During find resource", e);
			return null;
		}
	}
}
