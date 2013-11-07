use strict;
use warnings;
use Test::More;
use Test::Fatal;

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

subtest "Two functions closing over the same variable" => sub
{
	my $foo = Foo->new;
	
	is($x, 1);
	is($foo->inc, 2);
	is($foo->inc, 3);
	is($x, 3);
	is($foo->dec, 2);
	is($foo->dec, 1);
	is($x, 1);
};

package Goo {
	use Kavorka;
	
	method xyz {
		my @links;
		fun $xxx { push @links, 42 };
		$xxx->();
		return \@links;
	}
}

subtest "Closing over a variable in a lexical function" => sub
{
	is_deeply(Goo->xyz, [42]);
	is_deeply(Goo->xyz, [42]);
	is_deeply(Goo->xyz, [42]);
};

package Hoo {
	use Kavorka;
	method xyz ($closeme) {
		my $f = fun ($vvv = $closeme) { $vvv };
		return (\$closeme, $f);
	}
}

subtest "Closing over a variable in a default" => sub
{
	my ($X1, $fourtytwo) = Hoo->xyz(42);
	is($fourtytwo->(666), 666);
	is($fourtytwo->(), 42);
	
	my ($X2, $sixsixsix) = Hoo->xyz(666);
	is($sixsixsix->(999), 999);
	is($sixsixsix->(), 666);
	$$X2 = 777;
	is($sixsixsix->(), 777);
};

package Ioo {
	use Kavorka;
	method get_limit ($limit) {
		fun (Int $x where { $_ < $limit }) { 1 };
	}
}

subtest "Closing over a variable in a where {} block" => sub
{
	my $lim7 = Ioo->get_limit(7);
	ok $lim7->(6);
	ok exception { $lim7->(8) };
	
	my $lim12 = Ioo->get_limit(12);
	ok $lim12->(8);
	ok exception { $lim12->(14) };
	
	ok $lim7->(6);
	ok exception { $lim7->(8) };
};

done_testing;
