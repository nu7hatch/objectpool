require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Core extensions" do 
  it "should add #to_pool instance method to Class" do 
    Class.new.should respond_to :to_pool
  end 
  
  it "should add #pool? instance method to Class and Object" do 
    Class.new.should respond_to :pool?
    Object.new.should respond_to :pool?
    Class.new.pool?.should == false
    Object.new.pool?.should == false
  end
end

describe "An Class" do 
  context "on #to_pool call" do
    before do 
      @test_class = Class.new(Object)
      @pool = @test_class.to_pool(10)
    end
    
    it "should return itself ObjectPool powered when #to_pool method is called" do 
      @pool.pool?.should == true
      @pool.should include ObjectPool::InstanceMethods
      @pool.ancestors.should include @test_class
    end
    
    it "should save pool size in returned object" do 
      @pool.should respond_to :pool_size
      @pool.pool_size.should == 10
    end
    
    it "should save original class in returned object" do 
      @pool.should respond_to :pool_orig_class
      @pool.pool_orig_class.should == @test_class
    end
  end
end

describe "An ObjectPool powered class" do 
  before do 
    unless defined?(TestClass1)
      class TestClass1
        pool_methods :hello
        def hello(args)
          "Hello #{args}!"
        end
      end
    end 
  end

  context "on create" do 
    it "should start all workers in separated threads" do
      @pool = TestClass1.to_pool(10)
      @obj = @pool.new
      @obj.size.should == @obj.class.pool_size
    end
  end
  
  it "should allow to synchronously execute method in pool" do 
    @pool = TestClass1.to_pool(10)
    @obj = @pool.new
    result1 = @obj.hello("world").sync
    result2 = @obj.hello("again").sync
    result1.should == "Hello world!"
    result2.should == "Hello again!"
  end
  
  it "should allow to asynchronously execute method in pool" do 
    @pool = TestClass1.to_pool(10)
    @obj = @pool.new
    results = []
    20.times do |n|
      @obj.hello(n).async {|result| results << result; }
    end
    @obj.wait
    results.size.should == 20
    results.first.should match /^Hello \d+\!$/
  end
  
  it "should respect queue limit on methods execution" do 
    @pool = TestClass1.to_pool(20, :limit => 1)
    @obj = @pool.new
    @num = 0
    lambda do 
      Timeout::timeout(0.3) do 
        100.times do |n|
          @obj.hello(n).async { sleep 2 }
          @num += 1
        end
      end
    end.should raise_error(Timeout::Error)
    @num.should == @pool.pool_size + @pool.pool_queue_limit
  end
end
