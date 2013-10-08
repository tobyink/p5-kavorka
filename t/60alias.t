=pod

=encoding utf-8

=head1 PURPOSE

Test the C<alias> trait.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::More;
use Test::Fatal;

{
	package Example;
	use Kavorka;
	
	fun foo ($x is alias) {
		++$x;
	}
	
	fun bar (Int $x is alias) {
		++$x;
	}
}

my $x = 1;

is(Example::foo($x), 2);
is(Example::bar($x), 3);
is(Example::foo($x), 4);
is(Example::bar($x), 5);
is($x, 5);

{
	package Example2;
	use Kavorka;
	
	fun foo ($_ is alias) {
		++ $_;
	}
	
	fun bar (Int $_ is alias) {
		++ $_;
	}
}

my $y = 1;

is(Example2::foo($y), 2);
is(Example2::bar($y), 3);
is(Example2::foo($y), 4);
is(Example2::bar($y), 5);
is($y, 5);

done_testing;

