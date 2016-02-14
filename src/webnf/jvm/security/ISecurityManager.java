package webnf.jvm.security;

import java.security.Permission;

public interface ISecurityManager {
	ThreadGroup getThreadGroup();
	void checkPermission(Permission perm);
}
