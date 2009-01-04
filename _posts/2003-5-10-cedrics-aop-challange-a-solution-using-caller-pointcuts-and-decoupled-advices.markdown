--- 
wordpress_id: 4
layout: post
title: "Cedric's AOP challange: a solution using caller pointcuts and decoupled advices."
wordpress_url: http://jonasboner.com/?p=4
---
Last night I implemented caller pointcuts for <a href="http://aspectwerkz.sourceforge.net/">AspectWerkz</a>.  I just had to, since they have been haunting me since I read <a href="http://www.freeroller.net/page/cbeust">Cedric's</a> little <a href="http://beust.com/aop-thread.html">AOP challange</a>.

So for what it is worth, here is my way of implementing Cedric's caching problem using <a href="http://aspectwerkz.sourceforge.net/">AspectWerkz</a> and caller pointcuts.

I'll start with the cache advice. The <tt>CachingAdvice</tt>w caches the result and if the cache is used it reports it to the <tt>CacheStatistics</tt> instance:

<pre>
public class CachingAdvice extends MethodAdvice {

    protected Map m_cache = new StaticBucketMap(1000);

    public CachingAdvice() {
        super();
    }

    public Object execute(final JoinPoint joinPoint) 
        throws Throwable {
        MethodJoinPoint jp = (MethodJoinPoint)joinPoint;

        final Long hash = new Long(calculateHash(jp));
        final Object cachedResult = m_cache.get(hash);

        if (cachedResult != null) { 
            System.out.println("using cache");
            CacheStatistics.addCacheInvocation(
                jp.getMethodName(), jp.getParameterTypes());
            return cachedResult;
        }

        final Object result = joinPoint.proceed();

        m_cache.put(hash, result);
        return result;
    }

    private long calculateHash(final MethodJoinPoint jp) {
        int result = 17;
        result = 37 * result + jp.getMethodName().hashCode();
        Object[] parameters = jp.getParameters();
        for (int i = 0, j = parameters.length; i < j; i++) {
            result = 37 * result + parameters[i].hashCode();
        }
        return result;
    }
}
</pre>

The second advice I had to implement was the <tt>InvocationCounterAdvice</tt>. This advice will be applied on the caller side of the method invocation and simply reports the each invocation to the <tt>CacheStatistics</tt> instance:

</pre><pre>
public class InvocationCounterAdvice extends PreAdvice {

    public InvocationCounterAdvice() {
        super();
    }

    public void execute(final JoinPoint joinPoint) 
        throws Throwable {
        CallSideJoinPoint jp = (CallSideJoinPoint)joinPoint;
        CacheStatistics.addMethodInvocation(
            jp.getMethodName(), jp.getParameterTypes());
        joinPoint.proceed();
    }
}
</pre>

The next step was to define these advices and define where they should be applied:

<pre>
&lt;advice name="caching"
    class="examples.caching.CachingAdvice"
    deploymentModel="perInstance"/&gt;

&lt;advice name="invocationCounter"
    class="examples.caching.InvocationCounterAdvice"
    deploymentModel="perInstance"/&gt;

&lt;aspect class="examples.caching.Pi"&gt;
    &lt;pointcut type="method" pattern="getPiDecimal"&gt;
        &lt;advice-ref name="caching"/&gt;
    &lt;/pointcut&gt;
&lt;/aspect&gt;

&lt;aspect class=".*"&gt;
    &lt;pointcut type="callSide" pattern="examples.caching.Pi#getPiDecimal"&gt;
        &lt;advice-ref name="invocationCounter"/&gt;
    &lt;/pointcut&gt;
&lt;/aspect&gt;
</pre>

In this file I first defined the advices by giving them a name, specifying the class and the deployment model (scope). The second thing was to define the aspects and the pointcuts. By setting an aspect's class attribute to ".*" I am telling the system to apply its pointcuts to *all* classes. The pointcuts are defined by specifying the type (method/field/callSide etc.), the pattern (which methods should be advised) and last but not least the references to the advices that should be applied to these poincuts. The call side pointcut's pattern consists of the target class and the target method concatenated by a "#". (I don't know if this is the best syntax to describe this, but it works for now.)

Last I had to implement the <tt>CacheStatistics</tt> class (code not shown here) and a client class:

<pre>
public class CacheTest {
    public static void main(String[] args) {

        Pi.getPiDecimal(3);
        Pi.getPiDecimal(4);
        Pi.getPiDecimal(3);

        int methodInvocations = CacheStatistics.
            getNrOfMethodInvocationsFor(
                "getPiDecimal", new Class[]{int.class});
        int cacheInvocations = CacheStatistics.
            getNrOfCacheInvocationsFor(
                "getPiDecimal", new Class[]{int.class});

        double hitRate = methodInvocations / cacheInvocations;
        System.out.println("Hit rate: " + hitRate );
    }
}
</pre>

When running the client class it produces the following output:<br />
<pre>
using method
using method
using cache
Hit rate: 3.0
</pre>

The complete example can be checked out along with the aspectwerkz distribution from the AspectWerkz's <a href="http://aspectwerkz.sourceforge.net/cvs.html">CVS repository</a> (please note that this feature is still very much in development). You can run the example using <a href="http://maven.apache.org">Maven</a> by executing: <tt>maven aspectwerkz:samples:caching</tt>
