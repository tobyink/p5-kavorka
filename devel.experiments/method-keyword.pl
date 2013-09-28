use v5.14;
use warnings;
use Kavorka;
use Data::Dumper;

method foo (Int $x, $y, :www($w), Int %z) {
	print Dumper +{
		'$self'    => $self,
		'$x'       => $x,
		'$y'       => $y,
		'$w'       => $w,
		'%z'       => \%z,
	};
}

__PACKAGE__->foo( 123, "hiya", 'bum' => 999, 'www' => {} );
