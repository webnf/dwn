package webnf.jvm.security;

import java.security.Permission;

public class SecurityManager extends java.lang.SecurityManager {
	public final InheritableThreadLocal<ISecurityManager> ism_var;
	
	public SecurityManager() {
		this(null);
	}
	
	public SecurityManager(final ISecurityManager rootISM) {
		ism_var = new InheritableThreadLocal<ISecurityManager>() {
			@Override
			protected ISecurityManager initialValue() {
				return rootISM;
			}
		};		
	}
	
	@Override
	public ThreadGroup getThreadGroup() {
		ISecurityManager ism = ism_var.get();
		if (ism != null) {
			return ism.getThreadGroup();
		} else {
			return super.getThreadGroup();
		}
	}

	@Override
	public void checkPermission(Permission perm) {
		ISecurityManager ism = ism_var.get();
		if (ism != null) {
			ism.checkPermission(perm);
		} else {
			super.checkPermission(perm);
		}
	}
	
	@Override
	public void checkPermission(Permission perm, Object context) {
		ISecurityManager ism = ism_var.get();
		if (context instanceof ISecurityManager) {
			((ISecurityManager)context).checkPermission(perm);
		} else if (ism != null) {
			ism.checkPermission(perm);
		}
	}
	
	@Override
	public Object getSecurityContext() {
		ISecurityManager ism = ism_var.get();
		if (ism != null) {
			return ism;
		} else {
			return super.getSecurityContext();
		}
	}
}
