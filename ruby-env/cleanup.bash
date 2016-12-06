#!/bin/bash

rvm/bin/rvm cleanup all

# Remove tests
rm -rf rvm/rubies/ruby-*/lib/ruby/gems/*/gems/*/test
rm -rf rvm/rubies/ruby-*/lib/ruby/gems/*/gems/*/benchmark
rm -rf rvm/gems/ruby-*/gems/*/test
rm -rf rvm/gems/ruby-*/gems/*/tests
rm -rf rvm/gems/ruby-*/gems/*/spec

rm -rf rvm/gems/ruby-*/doc

rm -f rvm/gems/ruby-*/gems/*/TODO
rm -f rvm/gems/ruby-*/gems/*/README*
rm -f rvm/gems/ruby-*/gems/*/CHANGE*
rm -f rvm/gems/ruby-*/gems/*/Change*
rm -f rvm/gems/ruby-*/gems/*/COPYING*
rm -f rvm/gems/ruby-*/gems/*/LICENSE*
rm -f rvm/gems/ruby-*/gems/*/MIT-LICENSE*
rm -f rvm/gems/ruby-*/gems/*/*.txt
rm -f rvm/gems/ruby-*/gems/*/*.md
rm -f rvm/gems/ruby-*/gems/*/*.rdoc

rm -rf rvm/gems/ruby-*/gems/*/doc
rm -rf rvm/gems/ruby-*/gems/*/docs
rm -rf rvm/gems/ruby-*/gems/*/example
rm -rf rvm/gems/ruby-*/gems/*/examples
rm -rf rvm/gems/ruby-*/gems/*/sample
rm -rf rvm/gems/ruby-*/gems/*/doc-api

find rvm -name '*.md' | xargs rm -f
find rvm -name '.gitignore' | xargs rm -f
find rvm -name '.travis.yml' | xargs rm -f

find rvm -name '*.java' | xargs rm -f
find rvm -name '*.class' | xargs rm -f

rm -rf ./rvm/patches
rm -rf ./rvm/gems/cache
rm -rf ./rvm/gems/ruby-*/cache
rm -rf ./rvm/gem-cache

rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/cp949*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/euc_*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/shift_jis*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/koi8_*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/emacs*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/gb*
rm -f ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/big5*
rm -rf ./rvm/rubies/ruby-*/lib/ruby/*/*/enc/trans

# static library & stripping
rm -f ./rvm/rubies/ruby-*/lib/libruby-static.a
strip ./rvm/rubies/ruby-*/lib/libruby.so.*
find . -type f -name '*.so' | xargs -n1 strip

# rdoc
rm -rf ./rvm/rubies/ruby-*/lib/ruby/*/rdoc

# rakefiles
rm -f ./rvm/gems/ruby-*/gems/*/Rakefile
rm -f ./rvm/rubies/ruby-*/lib/ruby/gems/*/gems/*/Rakefile

# Remove misc unnecessary files
rm -rf lib/vendor/ruby/*/gems/*/.gitignore
rm -rf lib/vendor/ruby/*/gems/*/.travis.yml
rm -rf ./rvm/contrib
rm -rf ./rvm/patchsets
rm -rf ./rvm/man
find ./rvm/rubies/ruby-*/include -type f -name "*.h" | xargs rm -f
find ./rvm/gems/ruby-*/gems/*/ext -type f -name "*.o" | xargs rm -f
find ./rvm/gems/ruby-*/gems/*/ext -type f -name "*.h" | xargs rm -f
find ./rvm/gems/ruby-*/gems/*/ext -type f -name "*.c" | xargs rm -f
find ./rvm/gems/ruby-*/gems/*/ext -type f -name "mkmf.log" | xargs rm -f
find ./rvm/gems/ruby-*/gems/*/ext -type f -name "Makefile" | xargs rm -f

exit 0
