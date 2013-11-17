=pod

=encoding utf-8

=head1 PURPOSE

Test custom traits.

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

use Kavorka;

BEGIN {
	package Kavorka::TraitFor::Parameter::superbad;
	use Moo::Role;
	$INC{'Kavorka/TraitFor/Parameter/superbad.pm'} = __FILE__;
};

fun foo ($x is superbad) {
	42;
}

fun bar ($x is superbad(boom)) {
	42;
}

my ($foo,   $bar)   = map Kavorka->info( 'main'->can($_) ), qw/ foo bar /;
my ($foo_x, $bar_x) = map $_->signature->params->[0], $foo, $bar;

ok $foo_x->DOES('Kavorka::TraitFor::Parameter::superbad');
ok $bar_x->DOES('Kavorka::TraitFor::Parameter::superbad');
is_deeply(
	$bar_x->traits->{superbad},
	['boom'],
);

done_testing;

