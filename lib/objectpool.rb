require 'logger'
require 'timeout'

begin
  require 'fastthread' 
rescue LoadError
  require 'thread'
  $stderr.puts("The fastthread gem not found. Using standard ruby threads.")
end

module ObjectPool
  class Error < StandardError; end
  class StopWorker < Error; end

  def self.create(klass, size, opts={})
    (pool_klass = Class.new(klass)).class_eval do
      @__op__size        = size
      @__op__orig_class  = klass
      @__op__queue_limit = opts[:limit].to_i
      extend ClassMethods
      include InstanceMethods
      __op__redefine_pool_methods
    end
    pool_klass
  end
  
  module InstanceMethods
    def initialize(*args, &block)
      @__op__mx      = Mutex.new
      @__op__cv      = ConditionVariable.new
      @__op__queue   = Queue.new
      @__op__workers = ThreadGroup.new
      
      self.class.pool_size.times do
        __op__create_worker(*args, &block)
      end
    end
    
    def join
      sleep 0.01 until @__op__workers.list.all? {|w| !w.alive?}
    end
    
    def wait
      sleep 0.01 until @__op__mx.synchronize { @__op__queue.empty? && @__op__workers.list.all? {|w| !w.busy?} }
    end

    def size
      @__op__workers.list.size
    end
    
    def busy?
      @__op__mx.synchronize { @__op__queue.size < @__op__workers.list.size }
    end
    
    def close
      @__op__workers.list.each {|worker| worker.raise(StopWorker)}
      @__op__workers = ThreadGroup.new
    end
    
    private
    
    def __op__create_worker(*args, &block)
      @__op__workers.add(Thread.new do
        executor = self.class.pool_orig_class.new(*args, &block)
        action   = nil
        loop do
          begin
            @__op__mx.synchronize do 
              @__op__cv.wait(@__op__mx)
              if action = @__op__queue.shift
                Thread.current.lock_at_pool!
                @__op__mx.unlock 
                result = executor.send(action.method.to_sym, action.args, &action.block)
                action.complete!(result)
                @__op__mx.lock
                Thread.current.release_at_pool!
              end
            end
          rescue StopWorker
            break
          end
        end
      end)
    end
    
    def __op__call_at_pool(meth, *args, &block)
      if self.class.pool_queue_limit > 0
        sleep 0.01 until @__op__mx.synchronize { self.class.pool_queue_limit > @__op__queue.size }
      end
      Method.new(meth, args, block, @__op__mx, @__op__cv, @__op__queue)
    end
  end
  
  class Method
    class Error < StandardError; end
    class TerminatedError < Error; end
    
    attr_reader :method, :args, :block, :callback
    
    def initialize(method, args, block, mx, cv, queue)
      @method, @args, @block = method, args, block
      @mx, @cv, @queue = mx, cv, queue
      @complete = false
      @result = nil
    end
    
    def complete?
      @complete
    end
    
    def complete!(*opts)
      @callback.call(*opts)
      @complete = true
    end
    
    def async(&block)
      call_at_pool(false, &block)
    end
    alias_method :asynchronous, :async
    
    def sync
      call_at_pool(true)
    end
    alias_method :synchronous, :sync
    
    private
    
    def terminated?
      !!@terminated
    end
    
    def call_at_pool(synchronous=false, &block)
      unless terminated?
        @callback = block_given? && !synchronous ? block : proc {|r| @result = r}
        @mx.synchronize do 
          @queue << self
          @cv.signal
          @terminated = true
        end
        if synchronous
          sleep 0.01 until complete?
          return @result
        end
        return self
      end
      raise TerminatedError, "Can't run terminated method" 
    end
  end
  
  class Thread < ::Thread
    def busy?
      !!self[:busy]
    end
    
    def lock_at_pool!
      self[:busy] = true
    end
    
    def release_at_pool!
      self[:busy] = false
    end
  end
  
  module ClassMethods
    def __op__redefine_pool_methods
      pool_methods.each do |method|
        class_eval <<-EVAL
          def #{method.to_s}(*args, &block)
            __op__call_at_pool(:#{method.to_s}.to_sym, args, block)
          end
        EVAL
      end 
    end
  
    def pool?
      true
    end 
    
    def pool_size
      @__op__size
    end
    
    def pool_orig_class
      @__op__orig_class
    end
    
    def pool_queue_limit
      @__op__queue_limit
    end
  end
end

class Class
  def to_pool(size, opts={})
    ObjectPool.create(self, size, opts)
  end
  
  def pool?
    false
  end
  
  def pool_methods(*methods)
    if methods.size > 0
      __op__add_pool_methods(methods)
    else
      unless @pool_methods
        @pool_methods ||= []
        self.ancestors.each do |ancestor|
          @pool_methods.concat(ancestor.pool_methods) if ancestor.is_a?(Class)
        end
      end
    end
    @pool_methods
  end
  
  protected
  
  def __op__add_pool_methods(*methods)
    if pool_methods && methods.size > 0
      case m = methods.first
      when Array
        m.uniq.each { |method| __op__add_pool_methods(method) }
      when Symbol, String    
        @pool_methods << m unless pool_methods.include?(m)
      else
        raise ArgumentError, "Invalid method name"
      end
    end
  end
  
  def __op__remove_pool_methods(*methods)
    if pool_methods && methods.size > 0
      case m = methods.first
      when Array
        m.uniq.each { |method| __op__remove_pool_methods(method) }
      when Symbol, String    
        @pool_methods.delete(m)
      else
        raise ArgumentError, "Invalid method name"
      end
    end
  end
end

class Object
  def pool?
    false
  end
end

