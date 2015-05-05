[![Build Status](https://magnum.travis-ci.com/zendesk/curlybars.svg?token=Fh9oDUV4oikq9kNCExpq&branch=master)](https://magnum.travis-ci.com/zendesk/curlybars)
[![Code Climate](https://codeclimate.com/repos/54e48dda6956806595003bad/badges/eb0b90136be013596c9d/gpa.svg)](https://codeclimate.com/repos/54e48dda6956806595003bad/feed)
[![Test Coverage](https://codeclimate.com/repos/54e48dda6956806595003bad/badges/eb0b90136be013596c9d/coverage.svg)](https://codeclimate.com/repos/54e48dda6956806595003bad/feed)

Curlybars
=========

A fork of [Curly](https://github.com/zendesk/curly) that speaks Handlebars.

Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'curlybars'
```

And then execute:

```bash
bundle
```

Or install it yourself as:

```bash
gem install curlybars
```

How to use Curlybars
--------------------

In order to use Curlybars for a view or partial, use the suffix `.hbs` instead of
`.erb`, e.g. `app/views/posts/_comment.html.hbs`.

Curlybars will look for a corresponding presenter class named `Posts::CommentPresenter`.

By convention, these are placed in `app/presenters/`, so in this case the presenter would reside in `app/presenters/posts/comment_presenter.rb`. Note that presenters for partials are not prepended with an underscore.

There are 2 kinds of presenters in Curlybars:

- `Curlybars::Presenter`s
- P.O.R.O. presenters

#### The Compiler
- Uses RTLK in order to implement the lexer and the parser;
- AST nodes know how to compile themselves, and their children;
- Semantic checks at compile time:
 - check that opening and closing elements of helpers match.
- The target template embeds all the necessary presenter checks - runtime checking;
- Runtime checking is based on a whitelisting mechanism.
- Uses of scope gates to implements namespacing, e.g.:
 - {{#with context}} … {{/with}}
 - {{#each collection}} … {{/each}}
 - {{#block_helper context}} … {{/block_helper}}

#### The Language
- A path is an allowed and traversable chain of methods, like `movie.director`
- An expression is either a path, or a literal like a string, integer or boolean.
- Curlybars understands this Handlebars language subset:
 - {{helper [expression] [key=expression …]}}
 - {{#helper path [key=expression …]}} … {{/helper}}
 - {{#with path}} … {{/with}}
 - {{#each path}} … {{/each}}
 - {{#each path}} … {{else}} … {{/each}}
 - {{#if expression}} … {{/if}}
 - {{#if expression}} … {{else}} … {{/if}}
 - {{#unless expression}} … {{/unless}}
 - {{#unless expression}} … {{else}} … {{/unless}}
 - {{> partial}}
 - {{! … }}
 - {{!-- … --}}
 - {{~ … ~}}

#### Curlybars::Presenter
They are like `Curly::Presenter`s with some additions, and they are associated to views that are automatically looked up using the filename and the extension of the view file.
Furthermore they are responsible for the dynamic and static caching mechanism of Curly.
These are the methods available from Curly:
- `#setup!`
- `#cache_key`
- `#cache_options`
- `#cache_duration`
- `.version`
- `.depends_on`

#### P.O.R.O. presenters
They are just Plain Old Ruby Object you expose in your `hbs` templates. All you need is to extend `Curlybars::MethodWhitelist` module. This inclusion will implement a mechanism to declare which methods you want to expose into the view, integratind seamlessly with existing Object hierarchies.
It's for your convenience only, you can also do it yourself as long as your class
defines a `.allows_method?` it should work.

Helpers
-------

You can define custom helpers as normal method in your presenter.

Example:
```hbs
{{excerpt article.body max=400}}
```

```ruby
module HandlebarsHelpers
  extend Curlybars::MethodWhitelist
  allow_methods :excerpt

  def excerpt(context, options)
    max = options.fetch(:max, 120)
    context.to_s.truncate(max)
  end
end
```

It's a good practice to put your helpers into a module that you will include in different presenter, but you can also just put them as method of your presenter.

To implement the helper, one of the following signatures is needed:
```ruby
def helper()
def helper(context)
def helper(context, _)
def helper(_, options)
def helper(context, options)
```
The helper parameters can have different names from those in the example.

Note that if the helper has a different signature from all of those listed above, an exception will be thrown at rendering time - `Curlybars::Error::Render`

When the signature is actually broader than the argument specified in the template, default values are passed. Let's assume we have the following hbs:
```hbs
{{helper}}
```
and the following helper declaration:
```ruby
def helper(context, options)
```
what you actually get is `nil` as context, and `{}` as options, that has exactly the same effect of having the following signature:
```ruby
def helper(context = nil, options = {})
```
These mechanisms ensure that, unless the helper has a bad implementation, the hbs can never make the backend to raise an exception.

Block Helpers
-------------
You can also context helpers that takes a block.

Example:

```hbs
{{#form new_post class='red'}}
  <input type="text" name="body">
{{/form}}
```

```ruby
def form(context, options)
  klass = options[:class]
  action = context.action

  "<form class='#{klass}' action='#{action}'>#{yield}</form>"
end
```

Method Whitelisting
-------------------

Curlybars is designed to be used on the Help Center system at Zendesk.
We power many knowledge bases and communities that all require a unique look & feel.
We developed Curlybars to allow our customers freedom of implementing their own
layout while preserving the integrity of our system.

That's why Curlybars implements a paranoid declarative filter that defines which
methods are available in the presenters you are going to expose in the view.

```ruby
class PostPresenter
  extend Curlybars::MethodWhitelist
  allow_methods :title

  attr_reader :post

  def initialize(post)
    @post = post
  end

  def title
    post.original_title
  end
end
```

This will allow to use in the view:
```hbs
{{post.title}}
```

But not stuff like this:
```hbs
<!-- Call to #initialize on Post -->
{{post.initialize 'foobar'}}

<!-- Call to attribute reader post on Post hence caling directive the ActiveRecord -->
{{post.post.destroy}}
```

In the example above we might have inadvertently exposed `post` since it was
an `attr_reader` and not a method in the list of the public methods.
Same could happen if you include a module and forget that was defining a method.

Curlybars is paranoid about method leaking!

`Curlybars::Presenter` already extends `Curlybars::MethodWhitelist`.

Presenter namespacing
---------------------

By default Curlybars will follow the Curly's standard template name resolution.
Furthermore in Curlybars you can define a global namespace for all your
presenters associated with Handlebars `.hbs` views.

You just need to initialize Curlybars like this:

```ruby
# config/initializers/curlybars.rb
Curlybars.configure do |config|
  config.presenters_namespace = 'Experimental'
end
```

This will make the lookup system to search for presenters like:
```
Experimental::Articles::ShowPresenter
```

Exceptions
----------

Curlybars raises the following exceptions:
- `Curlybars::Error::Lex`
- `Curlybars::Error::Parse`
- `Curlybars::Error::Compile`
- `Curlybars::Error::Validate`
- `Curlybars::Error::Render`

Every exception object carries at least the following attributes that can be consumed:

 * id: a unique identifier for the exception
 * message: a generic error message that describes the encountered issue
 * position: a `Curlybars::Position` pointing to the exact location to the error. Meaningful for the `id`

### Lexer Errors

During the lexing phase, a `Curlybars::Error::Lex` exception can be raised.

Only one id is available for this exception: `lex`.

#### lex

Example - The following HBS raises this exception:
```hbs
{{! a string cannot be surrounded by two different types of quotes }}

{{t 'a string"}}
```

```hbs
{{! a path cannot be written using commas (only dots are valid) }}

{{first,second "a string"}}
```

### Parser Errors

During the parsing phase, a `Curlybars::Error::Parse` exception can be raised.

Only one id is available for this exception: `parse`.

#### parse

Example - The following HBS raises this exception:
```hbs
{{! #each can only iterate over a collection }}

{{#each 'a string'}}
{{/each}}
```

### Compiler Errors

During the compilation phase, a `Curlybars::Error::Compile` exception can be raised.

Only one id is available for this exception: `compile.closing_tag_mismatch`.

#### compile.closing_tag_mismatch

 Example - The following HBS raises this exception:
```hbs
{{! a block helper can only be closed by a tag with the same name }}

{{#foo}}
{{/bar}}
```

### Validation Errors

During the validation phase, a `Curlybars::Error::Validate` exception can be raised.

The following descriptors are available:
- `validate.closing_tag_mismatch`
- `validate.not_a_partial`
- `validate.not_a_presenter`
- `validate.not_a_presenter_collection`
- `validate.not_a_leaf`
- `validate.unallowed_path`

#### validate.closing_tag_mismatch

This exception occurs when a block helper is not closed properly. This means that each custom block helper must be closed by a tag with the same name. For example, the following example will raise this exception:

```hbs
{{! a block helper can only be closed by a tag with the same name }}

{{#foo}}
  ...
{{/bar}}
```

#### validate.not_a_partial

This exception occurs when a path is called as a partial but it's not given
the allowed methods definition on the presenter. For example, the following example will raise this exception:

```ruby
class NavigationPresenter
  allow_method menu: :partial

  def menu
    ...
  end
end
```

```hbs
{{! this will NOT raise the exception }}

{{> menu}}

{{! this will raise the exception }}

{{menu}}
```

#### validate.not_a_presenter

This exception occurs when a language construct that consumes a presenter is given a path that, according to its `allow_method` declaration, is not supposed to evaluate to a
presenter. For example, the following example will raise this exception:

```ruby
class ArticlePresenter
  allow_methods :title, author: AuthorPresenter

  def title
    "Niccolò Macchiavelli"
  end

  def author
    ...
  end
end
```

```hbs
{{! this will NOT raise the exception }}

{{#with author}}
  ...
{{/with}}

{{! this will raise the exception }}

{{#with title}}
  ...
{{/with}}
```

#### validate.not_a_presenter_collection

This exception occurs when a language construct that consumes a presenter is given a path that, according to its `allow_method` declaration, is not supposed to evaluate to a
collection of presenters. For example, the following example will raise this exception:

```ruby
class ArticlePresenter
  allow_methods :title, comments: [CommentPresenter]

  def title
    "Niccolò Macchiavelli"
  end

  def comments
    ...
  end
end
```

```hbs
{{! this will NOT raise the exception }}

{{#each comments}}
  ...
{{/each}}

{{! this will raise the exception }}

{{#each title}}
  ...
{{/each}}
```

#### validate.not_a_leaf

This exception occurs when a language construct that consumes a presenter is given a path that, according to its `allow_method` declaration, is not supposed to evaluate to a method that returns a terminal output. For example, the following example will raise this exception:

```ruby
class ArticlePresenter
  allow_methods :link, comments: [CommentPresenter]

  def link(url)
    "<a href='#{url}'>link</a>"
  end

  def comments
    ...
  end
end
```

```hbs
{{! this will NOT raise the exception }}

{{link 'http://test.com/cat.jpg'}}

{{! this will raise the exception }}

{{comments 'http://test.com/cat.jpg'}}
```

#### validate.unallowed_path

This exception occurs when a path is not allowed, given the allowed method definition
on the presenter. For example, the following example will raise this exception:

```ruby
class UserPresenter
  allow_methods :name

  def name
    "Nicolø"
  end
end
```

```hbs
{{! this will NOT raise the exception }}

{{ user.name }}

{{! this will raise the exception }}

{{ user.foo }}
```

### Rendering Errors

During the validation phase, a `Curlybars::Error::Render` exception can be raised.

The following descriptors are available:
- `render.context_is_not_a_presenter`
- `render.context_is_not_an_array_of_presenters`
- `render.invalid_helper_signature`
- `render.not_an_enumerable_or_hash`
- `render.path_not_allowed`
- `render.traverse_too_deep`
- `render.output_too_long`
- `render.timeout`

Contributing
------------

1. Fork the project
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Copyright and License
---------------------

Copyright (c) 2015 Zendesk Inc.
