--- 
wordpress_id: 134
layout: post
title: Clustering JRuby with Open Terracotta
excerpt: "<p>Yesterday I was spending some time thinking about the possibilities to cluster applications written in <a href=\"http://jruby.codehaus.org/\">JRuby</a> with <a href=\"http://www.terracotta.org/\">Open Terracotta</a>.</p>\r\n\
  <p>Sounds like a crazy idea? Well, I don\xC3\xA2\xE2\x82\xAC\xE2\x84\xA2t know. Perhaps it is. But thinking ahead a bit, with perhaps future deployments of <a href=\"http://www.rubyonrails.org/\">Ruby on Rails</a> applications etc. on JRuby makes it a bit more interesting. </p>\r\n\
  \r\n\
  <p>Anyway, let\xC3\xA2\xE2\x82\xAC\xE2\x84\xA2s give it a try. [..]</p>"
wordpress_url: http://jonasboner.com/2007/02/05/clustering-jruby-with-open-terracotta/
---
Yesterday I was spending some time thinking about the possibilities to cluster applications written in [JRuby](http://jruby.codehaus.org/) with [Open Terracotta](http://www.terracotta.org/).

Sounds like a crazy idea? Well, I don't know. Perhaps it is. But thinking ahead a bit, with perhaps future deployments of [Ruby on Rails](http://www.rubyonrails.org/) applications etc. on JRuby makes it a bit more interesting. 

Anyway, let's give it a try. 

# Chatter sample application

First let's start with writing a **very** simple chat application in JRuby.

<pre class="textmate-source mac_classic"><span class="source source_ruby"></span><span class="meta meta_require meta_require_ruby"></span><span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">require</span> <span class="string string_quoted string_quoted_single string_quoted_single_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">'</span>java<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">'</span>

<span class="meta meta_class meta_class_ruby"></span><span class="keyword keyword_control keyword_control_class keyword_control_class_ruby">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_ruby">Chatter</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> set the name and create a List to hold our messages
<span class="meta meta_function meta_function_method meta_function_method_without-arguments meta_function_method_without-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">initialize</span>
    <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">ARGV</span>[<span class="constant constant_numeric constant_numeric_ruby">0</span>]
    <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages = java.util.<span class="support support_class support_class_ruby">ArrayList</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>
    puts <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span><span class="constant constant_character constant_character_escape constant_character_escape_ruby"></span>--- Hi <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span>. Welcome to Chatter. Press Enter to refresh ---<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> takes text that the user enters
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 1) if enter is pressed -&gt; show the latest messages (refresh)
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 2) if text is entered -&gt; prepend the user name and add it to 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> the list of messages 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 3) display the messages
<span class="meta meta_function meta_function_method meta_function_method_without-arguments meta_function_method_without-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">run</span>
    <span class="keyword keyword_control keyword_control_ruby">while</span> <span class="constant constant_language constant_language_ruby">true</span> <span class="keyword keyword_control keyword_control_ruby keyword_control_ruby_start-block">do
</span>      print <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Enter Text&gt;&gt;<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span> 
      text = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">STDIN</span>.gets.chomp
      <span class="keyword keyword_control keyword_control_ruby">if</span> text.length &gt; <span class="constant constant_numeric constant_numeric_ruby">0</span> <span class="keyword keyword_control keyword_control_ruby">then</span> 
        <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages.add <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>[<span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="support support_class support_class_ruby">Time</span>.now<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span> -- <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span>] <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span>text<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span><span class="constant constant_character constant_character_escape constant_character_escape_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
        puts <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages
      <span class="keyword keyword_control keyword_control_ruby">else</span>
        puts <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages 
     <span class="keyword keyword_control keyword_control_ruby">end</span> 
    <span class="keyword keyword_control keyword_control_ruby">end</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>
<span class="keyword keyword_control keyword_control_ruby">end</span>

<span class="support support_class support_class_ruby">Chatter</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>.run
</pre>


# Run it

Now let's run it.

<pre>
--> jruby ./chat.rb Jonas 
                                                                                                  
--- Hi Jonas. Welcome to Chatter. Press Enter to refresh ---
Enter Text>>Hello. I am Jonas.
[[Fri Feb 02 11:57:56 CET 2007 -- Jonas] Hello. I am Jonas.
]
Enter Text>>Anybody there?
[[Fri Feb 02 11:57:56 CET 2007 -- Jonas] Hello. I am Jonas.
, [Fri Feb 02 11:58:01 CET 2007 -- Jonas] Anybody there?
]
Enter Text>>Ping...
[[Fri Feb 02 11:57:56 CET 2007 -- Jonas] Hello. I am Jonas.
, [Fri Feb 02 11:58:01 CET 2007 -- Jonas] Anybody there?
, [Fri Feb 02 11:58:25 CET 2007 -- Jonas] Ping...
]
Enter Text>>hmmm, no, seems to be just me
[[Fri Feb 02 11:57:56 CET 2007 -- Jonas] Hello. I am Jonas.
, [Fri Feb 02 11:58:01 CET 2007 -- Jonas] Anybody there?
, [Fri Feb 02 11:58:25 CET 2007 -- Jonas] Ping...
, [Fri Feb 02 11:58:59 CET 2007 -- Jonas] hmmm, no, seems to be just me
]
Enter Text>>
</pre>

Of course, this application is completely useless. It is in process, single threaded and only recieves input from STDIN, which means that it can only be used by one single user at a time.

But, what if we could make a single instance of the <code>@messages</code> list available on the network and then run multiple instances of the application (each on its own JVM instance, even on multiple machines) and have each one of them use this shared list? 

This would solve our problem and this in actually exactly what Open Terracotta could [conceptually] do for us. But Open Terracotta is a Java infrastructure service without any bindings or support for JRuby. So how can we proceed?

# Open Terracotta for JRuby

I can see two different ways we can bridge JRuby and Open Terracotta:

## Create a pattern language 

We could hook into and extend the Terracotta pattern matching language (the language that is used to pick out the shared state and the methods modifying it) to support the Ruby syntax. This would mean allowing the user to define the patterns based on the Ruby language but then, under the hood, actually map the Ruby syntax to the real Java classes that are generated by JRuby (this assumes using the compiler and not the interpreter). The benefit here is that it would be "transparent", in the same way as it is for regular Java applications. This is perhaps the best solution long term, but requires quite a lot of work and requires a fully working JRuby compiler. <ref>The development of the JRuby compiler has just started. When I tried it today it did not even compile the samples shipped with the distribution, so the Terracotta support for the compiler naturally has to wait until the implementation gets more complete and stable.</ref>

## Create a JRuby API

The minimal set of abstractions we need in this API is:

1. State sharing: Be able to pick out the state that should be shared - e.g. the top level "root" object of a shared object graph
2. State guarding: Be able to safely update this graph within the scope of a transaction

Ok, let's try to design this API.

# Designing the JRuby API

Most people are probably not aware of that Open Terracotta actually has an API that can do all this (and much more) for us. It is well hidden in the [SVN repository](http://svn.terracotta.org/fisheye/browse/Terracotta) and is used internally as the API for the hooks, added to the target application during the bytecode instrumentation process, to call. 

The class in question is the:  [<code>ManagerUtil</code>](http://svn.terracotta.org/fisheye/browse/Terracotta/branches/2.2.0/community/open/code/base/dso-l1/src/com/tc/object/bytecode/ManagerUtil.java).

So, everything we need is in the <code>ManagerUtil</code> class. But before we roll up our sleeves and start hacking on the glue code, let's take a step back and think through what we want out of the API from a user's perspective.

First we need to be able to create a "shared root", e.g. create a top-level instance of a shared object graph. One way of doing it would be to create some sort of factory method that can do the heavy lifting for us, similar to this:

<pre class="textmate-source mac_classic"><span class="source source_ruby"></span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages = createRoot java.util.<span class="support support_class support_class_ruby">ArrayList</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>
</pre>

Here we told some factory method <code>createRoot</code> to create a root instance of the type <code>java.util.ArrayList</code>. Seems reasonable I think. 

The other thing we need to do is to create some sort of transactions. We want to be able to start a transaction, lock the [shared] instance being updated, update it, unlock the instance and finally commit the transaction. Here is some basic pseudo code:

<pre>
lock target
    transaction begin
        modify target
    transaction commit
unlock target
</pre>

All steps except 'modify target' is done by infrastructure code. Code that has nothing to do with your business logic, code that we want to eliminate and "untangle" as much as possible. 

In Ruby, a common design pattern to accomplish this is to use a method that takes a [block/closure](http://en.wikipedia.org/wiki/Closure_(computer_science). Using this pattern we could design the API to look something like this:

<pre class="textmate-source mac_classic"><span class="source source_ruby">guard </span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages <span class="keyword keyword_control keyword_control_ruby keyword_control_ruby_start-block">do 
</span>  <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages.add msg
<span class="keyword keyword_control keyword_control_ruby">end</span>
</pre>

Here the semantics are: 

* the <code>@messages</code> list is guarded for concurrent access (both in a single JVM or in the cluster)
* the 'do' keyword takes the lock (on <code>@messages</code>) and initiates the transaction (unit of work)
* all updates to <code>@messages</code> that are done within the 'do-end' block are recorded in a change set (and are guaranteed to be done in isolation)
* when the 'end' of the block is reached then the transaction is committed, the change set is replicated and the lock (on <code>@messages</code>) is released

# Implementing the JRuby API

Now, let's take a look at the <code>ManagerUtil</code> class. It has a lot of useful stuff but the methods that we are currently interested in has the following signatures:

<pre class="textmate-source mac_classic"><span class="source source_java"></span><span class="support support_type support_type_built-ins support_type_built-ins_java">Object</span> lookupOrCreateRoot(<span class="support support_type support_type_built-ins support_type_built-ins_java">String</span> rootName, <span class="support support_type support_type_built-ins support_type_built-ins_java">Object</span> object);
<span class="storage storage_type storage_type_java">void</span> monitorEnter(<span class="support support_type support_type_built-ins support_type_built-ins_java">Object</span> obj, <span class="storage storage_type storage_type_java">int</span> lockType); 
<span class="storage storage_type storage_type_java">void</span> monitorExit(<span class="support support_type support_type_built-ins support_type_built-ins_java">Object</span> obj);
</pre>

Based on these methods we can create the following JRuby module implementing the requirements we outlined above (and let's put it in a flle called 'terracotta.rb' to be able to easily include it into the applications we want) :

<pre class="textmate-source mac_classic"><span class="source source_ruby">
</span><span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Usage: 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> # create an instance of 'foo' as a DSO root this 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> # means that it will be shared across the cluster
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> foo = DSO.createRoot "foo", Foo.new
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> # update 'foo' in a guarded block, get result back
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> result = DSO.guard foo, DSO::WRITE_LOCK do
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span>   foo.add bar
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span>   foo.getSum
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> end

<span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span> = com.tc.object.bytecode.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">ManagerUtil</span>

<span class="meta meta_module meta_module_ruby"></span><span class="keyword keyword_control keyword_control_module keyword_control_module_ruby">module</span> <span class="entity entity_name entity_name_type entity_name_type_module entity_name_type_module_ruby">DSO</span>
  
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> The different lock types
  <span class="variable variable_other variable_other_constant variable_other_constant_ruby">WRITE_LOCK</span> = com.tc.object.bytecode.<span class="support support_class support_class_ruby">Manager</span>::<span class="variable variable_other variable_other_constant variable_other_constant_ruby">LOCK_TYPE_WRITE</span>
  <span class="variable variable_other variable_other_constant variable_other_constant_ruby">READ_LOCK</span> = com.tc.object.bytecode.<span class="support support_class support_class_ruby">Manager</span>::<span class="variable variable_other variable_other_constant variable_other_constant_ruby">LOCK_TYPE_READ</span>
  <span class="variable variable_other variable_other_constant variable_other_constant_ruby">CONCURRENT_LOCK</span> = com.tc.object.bytecode.<span class="support support_class support_class_ruby">Manager</span>::<span class="variable variable_other variable_other_constant variable_other_constant_ruby">LOCK_TYPE_CONCURRENT</span>
  
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Creates a Terracotta shared root, 'name' is the name of the root
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> (can be anything that uniquily defines the root), 'object' is an
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> instance of the object to be shared. If the root the given name 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> already exists it simply returns it. 
<span class="meta meta_function meta_function_method meta_function_method_with-arguments meta_function_method_with-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">DSO.createRoot</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">(</span><span class="variable variable_parameter variable_parameter_function variable_parameter_function_ruby">name, object</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">)</span>
    guardWithNamedLock name, <span class="variable variable_other variable_other_constant variable_other_constant_ruby">WRITE_LOCK</span> <span class="keyword keyword_control keyword_control_ruby keyword_control_ruby_start-block">do
</span>      <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.lookupOrCreateRoot name, object
    <span class="keyword keyword_control keyword_control_ruby">end</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Creates a transaction and guards the object (passed in as the 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> 'object' argument) during the execution of the block passed into
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> the method. Similar to Java's synchronized(object) {...} blocks.
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Garantuees that the critical section is maintained correctly across 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> the cluster. The type of the lock can be one of: DSO:WRITE_LOCK, 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> DSO::READ_LOCK or DSO::CONCURRENT_LOCK (default is DSO:WRITE_LOCK).
<span class="meta meta_function meta_function_method meta_function_method_with-arguments meta_function_method_with-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">DSO.guard</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">(</span><span class="variable variable_parameter variable_parameter_function variable_parameter_function_ruby">object, type = </span><span class="variable variable_other variable_other_constant variable_other_constant_ruby">WRITE_LOCK</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">)</span>
    <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.monitorEnter object, type
    <span class="keyword keyword_control keyword_control_ruby">begin</span>
      <span class="keyword keyword_control keyword_control_pseudo-method keyword_control_pseudo-method_ruby">yield</span>
    <span class="keyword keyword_control keyword_control_ruby">ensure</span>
      <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.monitorExit object
    <span class="keyword keyword_control keyword_control_ruby">end</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Creates a transaction and guards the critical section using a virtual
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> so called 'named lock. It is held during the execution of the block 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> passed into the method. Garantuees that the critical section is 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> maintained correctly across the cluster. The type of the lock can 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> be one of: DSO:WRITE_LOCK, DSO::READ_LOCK or DSO::CONCURRENT_LOCK
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> (default is DSO:WRITE_LOCK)8.
<span class="meta meta_function meta_function_method meta_function_method_with-arguments meta_function_method_with-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">DSO.guardWithNamedLock</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">(</span><span class="variable variable_parameter variable_parameter_function variable_parameter_function_ruby">name, type = </span><span class="variable variable_other variable_other_constant variable_other_constant_ruby">WRITE_LOCK</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">)</span>
    <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.beginLock name, type
    <span class="keyword keyword_control keyword_control_ruby">begin</span>
      <span class="keyword keyword_control keyword_control_pseudo-method keyword_control_pseudo-method_ruby">yield</span>
    <span class="keyword keyword_control keyword_control_ruby">ensure</span>
      <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.commitLock name
    <span class="keyword keyword_control keyword_control_ruby">end</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>
  
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> Dispatches a Distributed Method Call (DMI). Ensures that the 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby">  </span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> particular method will be invoked on all nodes in the cluster.
<span class="meta meta_function meta_function_method meta_function_method_with-arguments meta_function_method_with-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">DSO.dmi</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">(</span><span class="variable variable_parameter variable_parameter_function variable_parameter_function_ruby">object, methodName, arguments</span><span class="punctuation punctuation_definition punctuation_definition_parameters punctuation_definition_parameters_ruby">)</span>
    <span class="variable variable_other variable_other_constant variable_other_constant_ruby">TC</span>.distributedMethodCall object, methodName, arguments
  <span class="keyword keyword_control keyword_control_ruby">end</span>
<span class="keyword keyword_control keyword_control_ruby">end</span>
</pre>

The <code>ManagerUtil</code> has a whole bunch of other useful and cool methods, such as for example <code>optimisticBegin</code>, <code>optimiticCommit</code> and <code>deepClone</code> for creating optimistic concurrency transactions, etc. But I'll leave these for a later blog post.

# Creating a distributed version of the Chatter application

Great. Now we have a JRuby API with all the abstractions needed to create a distributed version of our little chat application. What we have to do is simply to create the <code>@messsages</code> variable using the factory method for creating roots in the API. Then we also have to make sure that we guard the updating of the shared <code>java.util.ArrayList</code> using a guarded block. 

Let's take a look at the final version of the application. 

<pre class="textmate-source mac_classic"><span class="source source_ruby"></span><span class="meta meta_require meta_require_ruby"></span><span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">require</span> <span class="string string_quoted string_quoted_single string_quoted_single_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">'</span>java<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">'</span>
load <span class="string string_quoted string_quoted_single string_quoted_single_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">'</span>terracotta.rb<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">'</span>

<span class="meta meta_class meta_class_ruby"></span><span class="keyword keyword_control keyword_control_class keyword_control_class_ruby">class</span> <span class="entity entity_name entity_name_type entity_name_type_class entity_name_type_class_ruby">Chatter</span>
<span class="meta meta_function meta_function_method meta_function_method_without-arguments meta_function_method_without-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">initialize</span>
    <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">ARGV</span>[<span class="constant constant_numeric constant_numeric_ruby">0</span>]
    <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">DSO</span>.createRoot <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>chatter<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>, java.util.<span class="support support_class support_class_ruby">ArrayList</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>
    puts <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span><span class="constant constant_character constant_character_escape constant_character_escape_ruby"></span>--- Hi <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span>. Welcome to Chatter. Press Enter to refresh ---<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>
  
<span class="meta meta_function meta_function_method meta_function_method_without-arguments meta_function_method_without-arguments_ruby">  </span><span class="keyword keyword_control keyword_control_def keyword_control_def_ruby">def</span> <span class="entity entity_name entity_name_function entity_name_function_ruby">run</span>
    <span class="keyword keyword_control keyword_control_ruby">while</span> <span class="constant constant_language constant_language_ruby">true</span> <span class="keyword keyword_control keyword_control_ruby keyword_control_ruby_start-block">do
</span>      print <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Enter Text&gt;&gt;<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span> 
      text = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">STDIN</span>.gets.chomp
      <span class="keyword keyword_control keyword_control_ruby">if</span> text.length &gt; <span class="constant constant_numeric constant_numeric_ruby">0</span> <span class="keyword keyword_control keyword_control_ruby">then</span> 
        <span class="variable variable_other variable_other_constant variable_other_constant_ruby">DSO</span>.guard <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages <span class="keyword keyword_control keyword_control_ruby keyword_control_ruby_start-block">do
</span>          <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages.add <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>[<span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="support support_class support_class_ruby">Time</span>.now<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span> -- <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span><span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>name<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span>] <span class="source source_ruby source_ruby_embedded source_ruby_embedded_source"></span><span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">#{</span>text<span class="punctuation punctuation_section punctuation_section_embedded punctuation_section_embedded_ruby">}</span><span class="constant constant_character constant_character_escape constant_character_escape_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
          puts <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages
        <span class="keyword keyword_control keyword_control_ruby">end</span> 
      <span class="keyword keyword_control keyword_control_ruby">else</span>
        puts <span class="variable variable_other variable_other_readwrite variable_other_readwrite_instance variable_other_readwrite_instance_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_variable punctuation_definition_variable_ruby">@</span>messages 
     <span class="keyword keyword_control keyword_control_ruby">end</span> 
    <span class="keyword keyword_control keyword_control_ruby">end</span>
  <span class="keyword keyword_control keyword_control_ruby">end</span>
<span class="keyword keyword_control keyword_control_ruby">end</span>

<span class="support support_class support_class_ruby">Chatter</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>.run
</pre>


Pretty simple and fairly intuitive, right?

**Note 1**: Actually, we could have made it even more simple if we had taken a <code>java.util.concurrent.LinkedBlockingQueue</code> instead of a regular <code>java.util.ArrayList</code> as the list to hold our messages. If we would have done that then we could have skipped the <code>DSO.guard</code> block altogether since the Java concurrency abstractions are natively supported by Open Terracotta. But then I would have missed the opportunity to show you how to handle non-thread-safe data access. 

**Note 2**: It currently only works for sharing native Java classes. In other words, you can currently **not** cluster native JRuby constructs since it would mean cluster the internals of the JRuby interpreter (which is a lot of work and most likely not possible without rewriting parts of the interpreter). However, one feasible approach would be to not use the JRuby interpreter but the JRuby compiler and cluster its generated Java classes - but unfortunately the compiler is not ready for general use yet (see the footnote at the bottom). 

# Enable Open Terracotta for JRuby

In order to enable Open Terracotta for JRuby we have to add a couple of JVM options to the startup of our application, or add them directly in the <tt>jruby.(sh|bat)</tt> script.

You have to change:

<pre>
java -jar jruby.jar chat.rb
</pre>

to:

<pre>
java -Xbootclasspath/p:[path to terracotta boot jar] \
     -Dtc.config=path/to/your/tc-config.xml \
     -Dtc.install-root=[path to terracotta install dir] \
     -jar jruby.jar chat.rb    
</pre>

I know what you are thinking:

<blockquote>
"Hey! What's up with that <code>tc-config.xml</code> file? Do I have to write that? I hate XML!"
</blockquote>

Yes, unfortunately you have to feed Terracotta with a tiny bit of XML. This can perhaps be eliminated in the future (and replaced with a couple of command line options more or a JRuby config). But for now you have to write an XML file that  looks like this:

<pre class="textmate-source mac_classic"><span class="text text_xml"></span><span class="meta meta_tag meta_tag_preprocessor meta_tag_preprocessor_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;?</span><span class="entity entity_name entity_name_tag entity_name_tag_xml">xml</span><span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_xml"> version</span>=<span class="string string_quoted string_quoted_double string_quoted_double_xml"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_xml">"</span>1.0<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_xml">"</span><span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_xml"> encoding</span>=<span class="string string_quoted string_quoted_double string_quoted_double_xml"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_xml">"</span>UTF-8<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_xml">"</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">?&gt;</span>
<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_namespace entity_name_tag_namespace_xml">tc</span><span class="entity entity_name entity_name_tag entity_name_tag_xml"></span><span class="punctuation punctuation_separator punctuation_separator_namespace punctuation_separator_namespace_xml">:</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">tc-config</span> <span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_namespace entity_other_attribute-name_namespace_xml">xmlns</span><span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_xml"></span><span class="punctuation punctuation_separator punctuation_separator_namespace punctuation_separator_namespace_xml">:</span><span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_localname entity_other_attribute-name_localname_xml">tc</span>=<span class="string string_quoted string_quoted_double string_quoted_double_xml"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_xml">"</span>http://www.terracotta.org/config<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_xml">"</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">servers</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">server</span> <span class="entity entity_other entity_other_attribute-name entity_other_attribute-name_localname entity_other_attribute-name_localname_xml">name</span>=<span class="string string_quoted string_quoted_double string_quoted_double_xml"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_xml">"</span>localhost<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_xml">"</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">/&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">servers</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">clients</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">logs</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>%(user.home)/terracotta/jtable/client-logs<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">logs</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">clients</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">application</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">dso</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">instrumented-classes</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">include</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
          <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">class-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>*..*<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">class-expression</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
        <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">include</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
      <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">instrumented-classes</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
    <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">dso</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
  <span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">application</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
<span class="meta meta_tag meta_tag_xml"></span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&lt;/</span><span class="entity entity_name entity_name_tag entity_name_tag_namespace entity_name_tag_namespace_xml">tc</span><span class="entity entity_name entity_name_tag entity_name_tag_xml"></span><span class="punctuation punctuation_separator punctuation_separator_namespace punctuation_separator_namespace_xml">:</span><span class="entity entity_name entity_name_tag entity_name_tag_localname entity_name_tag_localname_xml">tc-config</span><span class="punctuation punctuation_definition punctuation_definition_tag punctuation_definition_tag_xml">&gt;</span>
</pre>

As you can see it contains the name of the server where the Terracotta server resides, the path to the logs and a statement that says; include all classes for instrumentation. That's it.

Now let's run it.

# Run the distributed Chatter

Here is an sample of me trying it out with my wife Sara. It shows my session window:

<pre>
--> jruby ./chat.rb Jonas         

--- Hi Jonas. Welcome to Chatter. Press Enter to refresh ---
Enter Text>>Hi there. Is it working?
[[Fri Feb 02 13:07:19 CET 2007 -- Jonas] Hi there. Is it working?
]
Enter Text>>
[[Fri Feb 02 13:07:19 CET 2007 -- Jonas] Hi there. Is it working?
, [Fri Feb 02 13:08:09 CET 2007 -- Sara] I think so, I could see your message when I clicked Enter
]
Enter Text>>Awesome!! Isn't this amazingly cool? Terracotta rocks!
[[Fri Feb 02 13:07:19 CET 2007 -- Jonas] Hi there. Is it working?
, [Fri Feb 02 13:08:09 CET 2007 -- Sara]  I think so, I could see your message when I clicked Enter
, [Fri Feb 02 13:08:59 CET 2007 -- Jonas] Awesome!! Isn't this amazingly cool? Terracotta rocks!
]
Enter Text>>
[[Fri Feb 02 13:07:19 CET 2007 -- Jonas] Hi there. Is it working?
, [Fri Feb 02 13:08:09 CET 2007 -- Sara]  I think so, I could see your message when I clicked Enter
, [Fri Feb 02 13:08:59 CET 2007 -- Jonas] Awesome!! Isn't this amazingly cool? Terracotta rocks!
, [Fri Feb 02 13:10:17 CET 2007 -- Sara] What do you mean? This is it? 
]
Enter Text>>Well, yeah...
[[Fri Feb 02 13:07:19 CET 2007 -- Jonas] Hi there. Is it working?
, [Fri Feb 02 13:08:09 CET 2007 -- Sara]  I think so, I could see your message when I clicked Enter
, [Fri Feb 02 13:08:59 CET 2007 -- Jonas] Awesome!! Isn't this amazingly cool? Terracotta rocks!
, [Fri Feb 02 13:10:17 CET 2007 -- Sara] What do you mean? This is it? 
, [Fri Feb 02 13:10:36 CET 2007 -- Jonas] Well, yeah...
]
Enter Text>>
</pre>

Well, I hope that you find it a bit more exciting... 

Feel like helping out? Drop me a line.

----
# And one more thing...

I also had some fun porting the JTable sample in the Open Terracotta distribution. It worked out nicely. I only had one problem and that was that I encountered a JRuby bug when trying to create a multi-dimensional <code>java.lang.Object</code> array. I was able to work around the bug by creating the array using reflection, but this unfortunately had the effect of making the final code much longer. Anyway, here is the code in case you want to try it out: 

<pre class="textmate-source mac_classic"><span class="source source_ruby"></span><span class="meta meta_require meta_require_ruby"></span><span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">require</span> <span class="string string_quoted string_quoted_single string_quoted_single_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">'</span>java<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">'</span>
load <span class="string string_quoted string_quoted_single string_quoted_single_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">'</span>terracotta.rb<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">'</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> need to create the object arrays using reflection 
<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> due to a bug in JRuby
tableHeader = java.lang.<span class="support support_class support_class_ruby">Object</span>[].<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>(<span class="constant constant_numeric constant_numeric_ruby">4</span>)
tableHeader[<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Time<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableHeader[<span class="constant constant_numeric constant_numeric_ruby">1</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Room A<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableHeader[<span class="constant constant_numeric constant_numeric_ruby">2</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Room B<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableHeader[<span class="constant constant_numeric constant_numeric_ruby">3</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Room C<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
dim = java.lang.reflect.<span class="support support_class support_class_ruby">Array</span>.newInstance(java.lang.<span class="support support_class support_class_ruby">Integer</span>::<span class="variable variable_other variable_other_constant variable_other_constant_ruby">TYPE</span>, <span class="constant constant_numeric constant_numeric_ruby">2</span>)
java.lang.reflect.<span class="support support_class support_class_ruby">Array</span>.setInt(dim, <span class="constant constant_numeric constant_numeric_ruby">0</span>, <span class="constant constant_numeric constant_numeric_ruby">9</span>)
java.lang.reflect.<span class="support support_class support_class_ruby">Array</span>.setInt(dim, <span class="constant constant_numeric constant_numeric_ruby">1</span>, <span class="constant constant_numeric constant_numeric_ruby">3</span>)
tableData = java.lang.reflect.<span class="support support_class support_class_ruby">Array</span>.newInstance(java.lang.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">Object</span>, dim)
tableData[<span class="constant constant_numeric constant_numeric_ruby">0</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>9:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">1</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>10:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">2</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>11:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">3</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>12:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">4</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>1:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">5</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>2:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">6</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>3:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">7</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>4:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
tableData[<span class="constant constant_numeric constant_numeric_ruby">8</span>][<span class="constant constant_numeric constant_numeric_ruby">0</span>] = <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>5:00<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>

<span class="comment comment_line comment_line_number-sign comment_line_number-sign_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_comment punctuation_definition_comment_ruby">#</span> create the model as a DSO root
model = <span class="variable variable_other variable_other_constant variable_other_constant_ruby">DSO</span>.createRoot <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>jtable.model<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>, javax.swing.table.<span class="support support_class support_class_ruby">DefaultTableModel</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>(tableData, tableHeader)

table = javax.swing.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">JTable</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>(model) 
frame = javax.swing.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">JFrame</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span> <span class="string string_quoted string_quoted_double string_quoted_double_ruby"></span><span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_begin punctuation_definition_string_begin_ruby">"</span>Table Demo<span class="punctuation punctuation_definition punctuation_definition_string punctuation_definition_string_end punctuation_definition_string_end_ruby">"</span>
frame.getContentPane().add(javax.swing.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">JScrollPane</span>.<span class="keyword keyword_other keyword_other_special-method keyword_other_special-method_ruby">new</span>(table))
frame.setDefaultCloseOperation javax.swing.<span class="variable variable_other variable_other_constant variable_other_constant_ruby">JFrame</span>::<span class="variable variable_other variable_other_constant variable_other_constant_ruby">EXIT_ON_CLOSE</span>
frame.setSize <span class="constant constant_numeric constant_numeric_ruby">500</span>, <span class="constant constant_numeric constant_numeric_ruby">200</span>
frame.pack
frame.setVisible <span class="constant constant_language constant_language_ruby">true</span>
</pre>
