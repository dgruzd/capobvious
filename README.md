# MobileDetect

mobile_detect is a lightweight gem for detecting mobile devices. It uses the user-agent string combined with specific HTTP headers to detect the mobile environment.

## Installation

Add this line to your application's Gemfile:

    gem 'capobvious'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capobvious

## Usage

If you want to use all recipes add to the end of Capfile  
    **require 'capistrano/ext/capobvious'**

### Recipes

```ruby
require 'capobvious/recipes/unicorn'
```

```ruby
require 'capobvious/recipes/db'
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
