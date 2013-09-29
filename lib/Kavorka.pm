use 5.014;
use strict;
use warnings;

use Carp ();
use Exporter::Tiny ();
use PadWalker ();
use Parse::Keyword ();
use Module::Runtime ();
use Scalar::Util ();
use Sub::Name ();

package Kavorka;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

our @ISA         = qw( Exporter::Tiny );
our @EXPORT      = qw( fun method );
our %EXPORT_TAGS = (
	modifiers => [qw( after around before )],
);

our %IMPLEMENTATION = (
	after        => 'Kavorka::Sub::After',
	around       => 'Kavorka::Sub::Around',
	before       => 'Kavorka::Sub::Before',
	classmethod  => 'Kavorka::Sub::ClassMethod',
	fun          => 'Kavorka::Sub::Fun',
	func         => 'Kavorka::Sub::Fun',
	function     => 'Kavorka::Sub::Fun',
	method       => 'Kavorka::Sub::Method',
	objectmethod => 'Kavorka::Sub::ObjectMethod',
);

our %INFO;

sub info
{
	my $me = shift;
	my $code = $_[0];
	$INFO{$code};
}

sub _exporter_expand_sub
{
	my $me = shift;
	my ($name, $args, $globals) = @_;
	
	my $implementation =
		$args->{'implementation'}
		// $IMPLEMENTATION{$name}
		// $me;
	
	Module::Runtime::use_package_optimistically($implementation)->can('parse')
		or Carp::croak("No suitable implementation for keyword '$name'");
	
	no warnings 'void';
	my $code = Sub::Name::subname(
		"$me\::$name",
		sub {
			$name; # close over name to prevent optimization
			my $subroutine = shift;
			$INFO{ $subroutine->body } = $subroutine;
			my @r = wantarray ? $subroutine->install_sub : scalar($subroutine->install_sub);
			Scalar::Util::weaken($subroutine->{body}) unless Scalar::Util::isweak($subroutine->{body});
			
			my $closed_over = PadWalker::closed_over($subroutine->{body});
			my $caller_vars = PadWalker::peek_my(1);
			$closed_over->{$_} = $caller_vars->{$_} for keys %$closed_over;
			PadWalker::set_closed_over($subroutine->{body}, $closed_over);
			
			wantarray ? @r : $r[0];
		},
	);
	
	Parse::Keyword::install_keyword_handler(
		$code => sub {
			my $subroutine = $implementation->parse;
			return (
				sub { ($subroutine, $args) },
				!! $subroutine->declared_name,
			);
		},
	);
	
	return ($name => $code);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Kavorka - function signatures with the lure of the animal

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

