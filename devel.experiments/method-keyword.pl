use v5.14;
use warnings;
use PerlX::Method;
use Data::Dumper;

method bar (
	Int $x where { $_ % 2 == 1 },
	$y ||= foo(1,2),
	Ref :www($w) = 1,
	slurpy HashRef[Int] $z,
) {
	$Data::Dumper::Sortkeys = 1;
	print Dumper({
		'$self'   => $self,
		'$w'      => $w,
		'$x'      => $x,
		'$y'      => $y,
		'$z'      => $z,
	});
}

__PACKAGE__->bar(123, "hiya", 'bum' => 999, 'www' => {});

fun guy (
	Int $x where { $_ % 2 == 1 },
	$y ||= foo(1,2),
	Ref :$w = 1,
	slurpy HashRef[Int] $z = (gomp => 1),
) {
	$Data::Dumper::Sortkeys = 1;
	print Dumper({
		'$w'      => $w,
		'$x'      => $x,
		'$y'      => $y,
		'$z'      => $z,
	});
}

guy(123, "hiya", 'w' => {bibble=>42});
