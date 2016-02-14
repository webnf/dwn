package webnf.jvm.threading;

public class ThreadGroup extends java.lang.ThreadGroup {
    public final Thread.UncaughtExceptionHandler ueh;
    public ThreadGroup(java.lang.ThreadGroup parent, String name, Thread.UncaughtExceptionHandler ueh) {
        super(parent, name);
        this.ueh = ueh;
    }
    public void uncaughtException(Thread thread, Throwable e) {
        ueh.uncaughtException(thread, e);
    }
}
