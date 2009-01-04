--- 
wordpress_id: 39
layout: post
title: Use Total Ordering of Objects to Avoid Deadlocks
wordpress_url: http://jonasboner.com/?p=39
---
Writing multi-threaded applications in Java can as you know be quite tricky, and if not done correctly, one can easily end up with deadlock situations.

For example, take a look at this little code snippet.  This piece of Java code implements a Node, which has three methods (that is of our interest):

<code lang="java">
Object get()
void set(Object o) 
void swap(Node n)
</code>

<p>
Here's the implementation:
</p>

<p>
<code lang="java">
public class Node {
    private Object value;
    public synchronized Object get() {
        return value;
    }
    public synchronized void set(Object value) {
        this.value = value;
    }
    public synchronized void swap(Node n) {
        Object tmp = get();
        set(n.get());
        n.set(tmp);
    }
   ... // remaining methods omitted 
}
</code>
</p>

This class might look okay, but it actually suffers from potential deadlock.  For example what happens if, one thread T1 invokes <tt>n1.swap(n2)</tt> while an other one T2 concurrently invokes <tt>n2.swap(n1) </tt>?

Thread T1 acquires the lock for node n1, and thread T2 acquires the lock for node n2.  Thread T1 now invokes <tt>n2.get()</tt> (in the <tt>swap(..)</tt> method). This invocation now has to wait since node n2 is locked by thread T2, this while the reverse holds for thread T2 (e.g. it needs to wait for node n1 which is locked by thread T1). Which means that we have a deadlock.

<p>
This program is however easily fixed by using the technique of totally ordering all objects in the system.
</p>

<p>
<code lang="java">
public class Node {
    private Object value;
    public synchronized Object get() {
        return value;
    }
    public synchronized void set(Object value) {
        this.value = value;
    }
    private synchronized void doSwap(Node n) {
        Object tmp = get();
        set(n.get());
        n.set(tmp);
    }
    public void swap(Node n) {
        if (this ==  n) {
            return;
        } else if (System.identityHashCode(this) < System.identityHashCode(n)) {
            doSwap(n);
       } else {
           n.doSwap(this);
       }
    }
   ... // remaining methods omitted 
}
</code></code></p>

<p>
In this program, all locks will be acquired in increasing order, guaranteed to be the same for all threads, and thereby avoiding deadlock situations.
</p>
