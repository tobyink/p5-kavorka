use strict;
use warnings;
use Test::More;

my $x;
BEGIN { $x = 1 };

package Foo {
	use Kavorka;
	method new ($class: ...) {
		bless {}, $class;
	}
	method inc { ++$x }
	method dec { --$x }
}

my $foo = Foo->new;

is($x, 1);
is($foo->inc, 2);
is($foo->inc, 3);
is($x, 3);
is($foo->dec, 2);
is($foo->dec, 1);
is($x, 1);

done_testing;
