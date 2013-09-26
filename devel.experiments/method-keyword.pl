use v5.14;
use warnings;
use PerlX::Method;
use Data::Dumper;


method bar (
	Int $x where { $_ % 2 == 1 },
	$y ||= foo(1,2),
	Ref :www($w) = 1,
	slurpy HashRef $z,
) :($;@) :method {
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
