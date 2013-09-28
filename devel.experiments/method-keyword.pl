use v5.14;
use warnings;

package Foo;

use Data::Dumper;
use Moo;
use Kavorka qw( around before method );

method foo (Int $x, $y, :www($w), Int %z) {
	print Dumper +{
		'$self'    => $self,
		'$x'       => $x,
		'$y'       => $y,
		'$w'       => $w,
		'%z'       => \%z,
	};
};

before foo ($x, $y, :$www, %z) {
	say "before foo: $x // $y";
};

around foo ($orig, $self: ...) {
	say "around 1";
	$self->$orig(@_);
	say "around 2";
}

__PACKAGE__->foo( 123, "hiya", 'bum' => 999, 'www' => {} );
