use 5.014;
use strict;
use warnings;

package Kavorka::Util;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.024';

use Carp;
use Exporter::Tiny ();

our @ISA        = qw( Exporter::Tiny );
our @EXPORT_OK  = qw( default );

sub default (\[$@%])
{
	require Devel::Caller;
	my $caller = Devel::Caller::caller_cv(1);
	my ($name) = Devel::Caller::called_with(0, 1);
	
	defined($name)
		or croak("Could not determine which variable to restore to default value; failed");
	
	my $caller_meta = 'Kavorka'->info($caller)
		or croak("Sub not declared using Kavorka? Failed");
	
	my $caller_sig = $caller_meta->signature
		or croak("Sub has not signature; failed");
	
	my ($param) = grep { $_->name eq $name } @{ $caller_sig->params }
		or croak("Variable '$name' is not a parameter; failed");
	
	my $default = $param->default;
	$default ||= sub { ;return } if $param->optional;
	
	$default or croak("Variable '$name' has no default; failed");
	
	${$_[0]} = $default->();
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Kavorka::Util - various utility functions for Kavorka users

=head1 DESCRIPTION

This module provides various utility functions that may be of use
within modules that use Kavorka.

The functions documented below are available for export, but are not
exported by default.

=over

=item C<< default $var >>

This function unconditionally sets/resets a variable to the default
declared in the signature.

   use Kavorka;
   use Kavorka::Util qw( default );
   
   fun foo ($x = 42) {
      say $x;
      default $x;   # reset to the default
      say $x;
   }
   
   foo();      # says "42" then "42"
   foo(33);    # says "33" then "42"

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<Kavorka>.

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

