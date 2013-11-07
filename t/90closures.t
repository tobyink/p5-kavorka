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

package Goo {
	use Kavorka;
	
	method xyz {
		my @links;
		fun $xxx { push @links, 42 };
		$xxx->();
		return \@links;
	}
}

is_deeply(Goo->xyz, [42]);
is_deeply(Goo->xyz, [42]);
is_deeply(Goo->xyz, [42]);


package Hoo {
	use Kavorka;
	
	method xyz ($x) {
		return (
			\$x,
			fun ($y = $x) { $y }
		);
	}
}

local $TODO = 'closures in defaults';

my ($X1, $fourtytwo) = Hoo->xyz(42);
is($fourtytwo->(666), 666);
is($fourtytwo->(), 42);

my ($X2, $sixsixsix) = Hoo->xyz(666);
is($sixsixsix->(999), 999);
is($sixsixsix->(), 666);
$$X2 = 777;
is($sixsixsix->(), 777);

done_testing;
