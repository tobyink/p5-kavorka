use 5.014;
use strict;
use warnings;

package PerlX::Method;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Class::Tiny qw( reference caller );
use Keyword::Simple qw();
use Text::Balanced qw( extract_codeblock extract_bracketed );

sub import
{
	my $class  = shift;
	my $caller = CORE::caller;
	
	Keyword::Simple::define method => sub
	{
		my $ref  = $_[0];
		my $self = $class->new(reference => $ref, caller => $caller);
		
		$self->_skip_space;
		
		my $subname = $self->_strip_name;
		my $params  = $self->_strip_params || $self->default_params('method');
		my $proto   = $self->_strip_prototype;
		my @attrs   = $self->_strip_attrs;
		
		use Data::Dumper;
		$Data::Dumper::Sortkeys = 1;
#			warn Dumper($subname, $params, $proto, \@attrs);
		
		$self->_skip_space;
		$$ref =~ s/\A\{// or die "expected block!";
		
		substr($$ref, 0, 0) = sprintf(
			'sub %s %s %s { %s ;;',
			($subname // ''),
			($proto ? "($proto)" : ''),
			join(' ', map {
				my ($attr, $attr_p) = @$_;
				defined($attr_p)
					? sprintf(':%s(%s)', $attr, $attr_p)
					: sprintf(':%s', $attr)
			} @attrs),
			$params->injections,
		);
		
		warn $$ref;
	}
}

sub signature_class
{
	require PerlX::Method::Signature;
	return 'PerlX::Method::Signature';
}

sub default_params
{
	my $self = shift;
	my ($kw) = @_;
	$self->signature_class->parse('$self: @_');
}

sub _skip_space
{
	my $ref = shift->{reference};
	
	my $X;
	while (
		($$ref =~ m{\A( \s+ )}x and $X = 1)
		or ($$ref =~ m{\A\#} and $X = 2)
	) {
		$X==2
			? ($$ref =~ s{\A\#.+?\n}{}sm)
			: substr($$ref, 0, length($1), '');
	}
	();
}

sub _strip_name
{
	my $self = shift;
	my $ref  = $self->{reference};
	
	$self->_skip_space;
	
	if ( $$ref =~ / \A ((?:\w|::)+) /x )
	{
		my $name = $1;
		substr($$ref, 0, length($name), '');
		return $name;
	}
	
	();
}

sub _strip_params
{
	my $self = shift;
	my $ref  = $self->{reference};
	
	$self->_skip_space;
	
	if ( $$ref =~ / \A \( /x )
	{
		my $extracted = extract_codeblock($$ref, '(){}[]<>', undef, '()');
		$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		return $self->signature_class->parse($extracted, package => $self->{caller});
	}
	
	();
}

sub _strip_prototype
{
	my $self = shift;
	my $ref  = $self->{reference};
	
	$self->_skip_space;
	
	if ( $$ref =~ / \A \: \s* \( /xsm )
	{
		$$ref =~ s/\A\:\s*//;
		
		my $extracted = extract_bracketed($$ref, '()');
		$extracted =~ s/(?: \A\( | \)\z )//xgsm;
		return $extracted;
	}
	
	();
}

sub _strip_attrs
{
	my $self = shift;
	my $ref  = $self->{reference};
	my @attrs;
	
	$self->_skip_space;
	
	if ($$ref =~ /\A:/)
	{
		substr($$ref, 0, 1, '');
		$self->_skip_space;
	}
	
	while ($$ref =~ /\A([^\W0-9]\w+)/)
	{
		my $name = $1;
		substr($$ref, 0, length($name), '');
		$self->_skip_space;
		
		my $extracted;
		if ($$ref =~ /\A\(/)
		{
			$extracted = extract_codeblock($$ref, '(){}[]<>', undef, '()');
			$extracted =~ s/(?: \A\( | \)\z )//xgsm;
			$self->_skip_space;
		}
		
		if ($$ref =~ /\A:/)
		{
			substr($$ref, 0, 1, '');
			$self->_skip_space;
		}
		
		push @attrs, [ $name => $extracted ];
	}
	
	@attrs;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

PerlX::Method - a module that does something-or-other

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=PerlX-Method>.

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

