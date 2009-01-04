--- 
wordpress_id: 17
layout: post
title: Role-Based Security the AOP way
wordpress_url: http://jonasboner.com/?p=17
---
<p>
Since the last example of the new 'annotation-defined aspects' model in AspectWerkz seemed to have caused a lot of confusion and made people miss the point, I will in this post try to give a more detailed explaination of the previous 'Role-Based Security' example.
</p>
<p>
First I just want to stress that this new model of defining the aspects will NOT in any sense make the old pure XML based and the doclet based approaches obsolete. We are here simply providing a new option. A ticket out of deployment descriptor hell. 

<p />
I also would like to mention that this new model is completely user-demand driven. It solely exists due to the fact that there is a high need for it. It basically solves three problems that the users have been complaining about:

<ul>
    <li>
Separation of implementation and definition. The implementation and the definition are defined in one single file (in the same bytecode). The aspect definition is thus not separated from the aspect implementation
    </li>
    <li>
        All advices and introductions needed to implement a concern can be implemented in one single class. The problem with the old approach was that you f.e. for a regular Aspect with two advices and an introduction needed four files. One for each advice and introductions as well as one for the definition. This felt like EJB all over again and the new model addresses this problem in a neat way allowing you to implement everything that is needed in one single class. 
    </li>
    <li>
        Not pure Java. Even though XML is widely used in the J2EE community and intuitive to most users, it is not Java. It suffers from problems with refactoring, maintainance, reusability etc. This new model tries to address this as well. Even thought the current implementation, based on JavaDoc tags, is not pure Java, it is closer to it and it will be pure Java when we have Java 1.5. Which is what this new model is targetting. 
    </li>
</ul>

<p />
So lets get back to the 'Role-Based Security' example of ours.

<p />
The first thing we do is to implement an abstract aspect that contains all implementation for this concern (the advices). But we leave the definition of the pointcuts (where to apply the advices) for later:

<pre>
    /**
     * @Aspect perThread
     */
    public abstract class AbstractRoleBasedAccessController extends Aspect {

        protected Subject m_subject = null;

        protected final SecurityManager m_securityManager = ...

        /** To be defined by the concrete aspect. */
        Pointcut authenticationPoints;

        /** To be defined by the concrete aspect. *
        Pointcut authorizationPoints;

        /** 
         * @Around authenticationPoints 
         */
        public Object authenticateUser(JoinPoint joinPoint) throws Throwable {
            if (m_subject == null) {
               // no subject => authentication required
               Context ctx = ... // get the principals and credentials
               m_subject = m_securityManager.authenticate(ctx); // throws an exception if not authenticated
            }
            Object result = Subject.doAsPrivileged(
               m_subject, new PrivilegedExceptionAction() {
                  public Object run() throws Exception {
                     return joinPoint.proceed();
                  };
               }, null
            );
            return result;
        }

        /** 
         * @Around authorizationPoints 
         */
        public Object authorizeUser(JoinPoint joinPoint) throws Throwable {
           MethodJoinPoint jp = (MethodJoinPoint)joinPoint;

           if (m_securityManager.checkPermission(
              m_subject, 
              jp.getTargetClass(), 
              jp.getMethod())) {

              // user is authorized => proceed
              return joinPoint.proceed();
           }
           else {
              throw new SecurityException(...);
           }
        }
    }
</pre>
 
<p />
This aspect is now completely generic and reusable. 

<p />
Now we can compile this aspect and package it in a library along with the implementation for the security manager etc. The aspect needs to be compiled with a custom compiler which retrieves the attributes and puts them in into the bytecode of the aspect class. This step will not be needed when we are running java 1.5 which has build in support for metadata annontations.

<p />
If we now want to use this security aspect of ours we can inherit the abstract aspect using regular class inheritance and define the pointcuts in the concrete subclass:

<pre>
    /**
     * @Aspect perThread
     */
    public class RoleBasedAccessController extends AbstractRoleBasedAccessController {

       /**
        * @Execution * *..facade.*.*(..)
        */
       Pointcut authenticationPoints;

       /**
        * @Execution * *..service.*.*(..)
        */
       Pointcut authorizationPoints;
    }
</pre>

<p />
The system needs to know which aspects we want to use and for this we need to write a TINY XML definition file. Here we only need to specify the names of the aspects and NO definition metadata:

<pre>
    &lt;aspectwerkz&gt;
        &lt;system id="security-test"&gt;
            &lt;package name="example"&gt;
                &lt;use-aspect class="RoleBasedAccessController"&gt;
                    &lt;param name="type" value="JAAS"&gt;
                &lt;/use-aspect&gt;
            &lt;/package&gt;
        &lt;/system&gt;
    &lt;/aspectwerkz&gt;
</pre>

<p />
Here we can see that I have the possibility of parameterizing the aspect. This can be very useful in some situations since it allows you to use the same aspect with different configurations in different contexts

<p />
If you think that inheritance adds too much coupling then you have the option of skipping the concrete subclass completely and define the pointcuts in the XML definition instead:

<pre>
    &lt;aspectwerkz&gt;
        &lt;system id="security-test"&gt;
            &lt;package name="example"&gt;
                &lt;use-aspect class="AbstractRoleBasedAccessController"&gt;
                    &lt;pointcut-def name="authenticationPoints" type="execution" pattern="* *..facade.*.*(..)"/&gt;
                    &lt;pointcut-def name="authorizationPoints" type="execution" pattern="* *..service.*.*(..)"/&gt;
                &lt;/use-aspect&gt;
            &lt;/package&gt;
        &lt;/system&gt;
    &lt;/aspectwerkz&gt;
</pre>

<p />
If you want to play with this new release (which is a release candidate) you can download it <a href="http://aspectwerkz.codehaus.org/releases.html">here</a>.

<p /></p>
