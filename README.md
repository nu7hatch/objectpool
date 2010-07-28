# Object Pool

Little bit different and magical implementation of thread pool pattern in ruby.

## Installation

    gem install objectpool

## Examples

    require 'objectpool'

    class MyClass 
      pool_methods :one, :two
      
      def one; sleep 1; end
      def two(arg) sleep 2; return arg end
    end 
    
    pool = MyClass.to_pool(10).new
    pool.one.async    # the `one` method will be called asynchronously
    pool.two(2).sync  # this will be called synchronously and it will return result
    # Result can be handled inside the asynchronous block
    pool.two(2).async {|result| puts result }
    
    # Now you can wait for results
    pool.wait
    
    # "Join" infinity loop with main thread...
    pool.join
    
    # ... or close this object pool
    pool.close

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Kriss Kowalik. See LICENSE for details.
