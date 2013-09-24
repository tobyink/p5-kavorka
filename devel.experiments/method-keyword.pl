use v5.14;
use warnings;
use PerlX::Method;

method bar ($self : Int $x where { $_ % 2 == 0 }, $y = foo(1,2), $, HashRef :www($w), ArrayRef[Str] :$z? is foo is bar = [qw/Hello world/]) : ($;@) {
	say $_[0];
}

__PACKAGE__->bar(123, "hiya");
