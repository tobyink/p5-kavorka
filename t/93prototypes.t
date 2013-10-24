=pod

=encoding utf-8

=head1 PURPOSE

Check prototypes work.

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

use Kavorka;

fun foo :($) { 1 }
fun bar :prototype($) { 1 }
my $baz  = fun :($) { 1 };
my $quux = fun :prototype($) { 1 };

is(prototype(\&foo), '$');
is(prototype(\&bar), '$');
is(prototype($baz),  '$');
is(prototype($quux), '$');

done_testing;
