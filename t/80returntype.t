=pod

=encoding utf-8

=head1 PURPOSE

Test return types.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use utf8;
use warnings;
use Test::More;
use Test::Fatal;

use Kavorka;

fun add1 ($a, $b → Int) {
	return $a + $b;
}

is( add1(4,5), 9 );
is( add1(4.1,4.9), 9 );

ok exception { my $r = add1(4.1, 5) };

use Types::Standard ();
use constant Rounded => Types::Standard::Int()->plus_coercions(Types::Standard::Num(), q[int($_)]);

fun add2 ($a, $b --> (Rounded) does coerce) {
	return $a + $b;
}

is( add2(4,5), 9 );
is( add2(4.1,4.9), 9 );
is( add2(4.1,5), 9 );

done_testing;
