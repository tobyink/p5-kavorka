use v5.14;
use warnings;
use PerlX::Method;
use Data::Dumper;


method bar (
	$self:
	Int $x where { $_ % 2 == 1 },
	$y ||= foo(1,2),
	slurpy HashRef $z,
) :($;@) :method {
	$Data::Dumper::Sortkeys = 1;
	print Dumper({
		'$self'   => $self,
		'$x'      => $x,
		'$y'      => $y,
		'$z'      => $z,
	});
	print __LINE__;
}

__PACKAGE__->bar(123, "hiya", 'bum' => 999, 'www' => {});
