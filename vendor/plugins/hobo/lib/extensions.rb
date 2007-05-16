module Kernel
  
  def extract_options_from_args!(args) #:nodoc:
    args.last.is_a?(Hash) ? args.pop : {}
  end

end

class Object

  def in?(array)
    array.include?(self)
  end

  def not_in?(array)
    not array.include?(self)
  end
  
  alias_method :is_a_without_multiple_args?, :is_a?
  def is_a?(*args)
    args.any? {|a| is_a_without_multiple_args?(a) }
  end
  
  # metaid
  def metaclass; class << self; self; end; end
  def meta_eval &blk; metaclass.instance_eval &blk; end

  # Adds methods to a metaclass
  def meta_def name, &blk
    meta_eval { define_method name, &blk }
  end

  # Defines an instance method within a class
  def class_def name, &blk
    class_eval { define_method name, &blk }
  end

end


class Module
  
  def inheriting_attr_accessor(*names)
    for name in names
      class_eval %{
        def #{name}
          if defined? @#{name}
            @#{name}
          elsif superclass.respond_to?('#{name}')
            superclass.#{name}
          end
        end
      }
    end
  end
  
  # Custom alias_method_chain that won't cause inifinite recursion if
  # called twice.
  # Calling alias_method_chain on alias_method_chain
  # was just way to confusing, so I copied it :-/
  def alias_method_chain(target, feature)
    # Strip out punctuation on predicates or bang methods since
    # e.g. target?_without_feature is not a valid method name.
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?
    without = "#{aliased_target}_without_#{feature}#{punctuation}"
    unless without.in?(instance_methods)
      alias_method without, target
      alias_method target, "#{aliased_target}_with_#{feature}#{punctuation}"
    end
  end

  
  # Fix delegate so it doesn't go bang if 'to' is nil
  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, "Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, :to => :greeter)."
    end

    methods.each do |method|
      module_eval(<<-EOS, "(__DELEGATION__)", 1)
        def #{method}(*args, &block)
          (_to = #{to}) && _to.__send__(#{method.inspect}, *args, &block)
        end
      EOS
    end
  end


end

module Enumerable

  def omap(method = nil, &b)
    if method
      map(&method)
    else
      map {|x| x.instance_eval(&b)}
    end
  end

  def oselect(method = nil, &b)
    if method
      select(&method)
    else
      select {|x| x.instance_eval(&b)}
    end
  end

  def ofind(method=nil, &b)
    if method
      find(&method)
    else
      find {|x| x.instance_eval(&b)}
    end
  end

  def search(not_found=nil)
    each do |x|
      val = yield(x)
      return val if val
    end
    not_found
  end

  def oany?(method=nil, &b)
    if method
      any?(&method)
    else
      any? {|x| x.instance_eval(&b)}
    end
  end

  def oall?(method=nil, &b)
    if method
      all?(&method)
    else
      all? {|x| x.instance_eval(&b)}
    end
  end

  def every(proc)
    map(&proc)
  end
  
  def map_with_index
    res = []
    each_with_index {|x, i| res << yield(x, i)}
    res
  end

end

class Hash

  def self.build(array)
    array.inject({}) do |res, x|
      k, v = yield x
      res[k] = v
      res
    end
  end

  def select_hash(new_keys=nil)
    res = {}
    if block_given?
      each {|k,v| res[k] = v if yield(k,v) }
    else
      new_keys.each {|k| res[k] = self[k] if self.has_key?(k)}
    end
    res
  end
  
  def map_hash
    res = {}
    each {|k,v| res[k] = yield(k,v) }
    res
  end

  #alias_method :hobo_original_reject, :reject
  def rejectX(keys=nil, &b)
    if b
      hobo_original_reject(&b)
    else
      res = {}.update(self) # can't use dup because it breaks with symbols
      keys.each {|k| res.delete(k)}
      res
    end
  end

  def partition_hash(keys=nil)
    yes = {}
    no = {}
    each do |k,v|
      if block_given? ? yield(k,v) : keys.include?(k)
        yes[k] = v
      else
        no[k] = v
      end
    end
    [yes, no]
  end
  
end

class <<ActiveRecord::Base
  alias_method :[], :find
end


# --- Fix Chronic - can't parse '12th Jan' --- #
begin
  require 'chronic'
  
  module Chronic
    
    class << self
      def parse_with_hobo_fix(s)
        parse_without_hobo_fix(if s =~ /^\s*\d+\s*(st|nd|rd|th)\s+[a-zA-Z]+(\s+\d+)?\s*$/
                                 s.sub(/\s*\d+(st|nd|rd|th)/) {|s| s[0..-3]}
                               else
                                 s
                               end)
      end
      alias_method_chain :parse, :hobo_fix
    end
  end
rescue MissingSourceFile; end



# --- Fix pp dumps - these break sometimes without this --- #
require 'pp'
module PP::ObjectMixin

  alias_method :orig_pretty_print, :pretty_print
  def pretty_print(q)
    orig_pretty_print(q)
  rescue
    "[#PP-ERROR#]"
  end

end

