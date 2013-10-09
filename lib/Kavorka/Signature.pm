use 5.014;
use strict;
use warnings;

use Kavorka::Signature::Parameter ();

package Kavorka::Signature;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.000_11';

use Parse::Keyword {};
use Parse::KeywordX;

use Moo;
use namespace::sweep;

has package         => (is => 'ro');
has _is_dummy       => (is => 'ro');
has params          => (is => 'ro',  default => sub { +[] });
has has_invocants   => (is => 'rwp', default => sub { +undef });
has has_named       => (is => 'rwp', default => sub { +undef });
has has_slurpy      => (is => 'rwp', default => sub { +undef });
has yadayada        => (is => 'rwp', default => sub { 0 });
has parameter_class => (is => 'ro',  default => sub { 'Kavorka::Signature::Parameter' });
has last_position   => (is => 'lazy');

sub parse
{
	my $class = shift;
	my $self = $class->new(@_);
	
	lex_read_space;
	
	my $found_colon = 0;
	while (lex_peek ne ')')
	{
		if (lex_peek(3) eq '...')
		{
			$self->_set_yadayada(1);
			lex_read(3);
			lex_read_space;
			die "After yada-yada, expected right parenthesis" unless lex_peek eq ")";
			next;
		}
		
		push @{$self->params}, $self->parameter_class->parse(package => $self->package);
		lex_read_space;
		
		my $peek = lex_peek;
		if ($found_colon and $peek eq ':')
		{
			die "Cannot have two sets of invocants - unexpected colon!";
		}
		elsif ($peek eq ':')
		{
			$_->traits->{invocant} = 1 for @{$self->params};
			$self->_set_has_invocants( scalar @{$self->params} );
			lex_read(1);
		}
		elsif ($peek eq ',')
		{
			lex_read(1);
		}
		elsif (lex_peek eq ')')
		{
			last;
		}
		else
		{
			die "Unexpected!! [$peek]"
		}
		
		lex_read_space;
	}
	
	$self->sanity_check;
	
	return $self;
}

# XXX - check not allowed optional parameters and named parameters in same sig
sub sanity_check
{
	my $self = shift;
	
	my $has_invocants = 0;
	my $has_slurpy = 0;
	my $has_named = 0;
	for my $p (reverse @{ $self->params or die })
	{
		$has_named++ if $p->named;
		$has_slurpy++ if $p->slurpy;
		
		if ($p->invocant) {
			$has_invocants++;
			next;
		}
		elsif ($has_invocants) {
			$has_invocants++;
			$p->traits->{invocant} = 1;  # anything prior to an invocant is also an invocant!
		}
	}
	$self->_set_has_invocants($has_invocants);
	$self->_set_has_named($has_named);
	$self->_set_has_slurpy($has_slurpy);
	
	my $i = 0;
	for my $p (@{ $self->params })
	{
		next if $p->invocant;
		$p->_set_position($i++);
	}
	
	my $zone = 'positional';
	for my $p (@{ $self->params })
	{
		# Zone transitions
		if ($zone eq 'positional')
		{
			($zone = 'named'  && next ) if $p->named;
			($zone = 'slurpy' && next ) if $p->slurpy;
		}
		elsif ($zone eq 'named')
		{
			($zone = 'slurpy' && next ) if $p->slurpy;
		}
		
		my $p_type = $p->slurpy ? 'slurpy' : $p->named ? 'named' : 'positional';
		die "Found $p_type parameter after $zone; forbidden" if $p_type ne $zone;
	}
	
	$_->sanity_check($self) for @{ $self->params };
	
	#use Data::Dumper; print Dumper($self);
	
	();
}

sub _build_last_position
{
	my $self = shift;
	my ($last) = reverse( $self->positional_params );
	return -1 unless $last;
	return $last->position;
}

sub injection
{
	my $self = shift;
	my $str;
	
	my (@positional, @named, @slurpy);
	for my $p (@{$self->params})
	{
		if ($p->slurpy)     { push @slurpy, $p }
		elsif ($p->named)   { push @named, $p }
		else                { push @positional, $p }
	}
	
	my (@req_positional, @opt_positional, @req_named, @opt_named);
	push @{ $_->optional ? \@opt_positional : \@req_positional }, $_ for @positional;
	push @{ $_->optional ? \@opt_named : \@req_named }, $_ for @named;

	unless (@named or $self->yadayada or @slurpy)
	{
		my $min = scalar(@req_positional);
		my $max = scalar(@req_positional) + scalar(@opt_positional);
		my $invs = grep $_->invocant, @req_positional;
		
		$str .= $min==$max
			? sprintf('Carp::croak("Expected %d parameters") unless @_ == %d;', $min - $invs, $min)
			: sprintf('Carp::croak("Expected between %d and %d parameters") unless @_ >= %d && @_ <= %d;', $min - $invs, $max - $invs, $min, $max);
	}

	$str .= join qq[], map($_->injection($self), @positional), q[];
	
	if (@named
	or @slurpy && $slurpy[0]->name =~ /\A\%/
	or @slurpy && $slurpy[0]->name =~ /\A\$/ && $slurpy[0]->type->is_a_type_of(Types::Standard::HashRef()))
	{
		require Data::Alias;
		my @allowed_names = map +($_=>1), map @{$_->named_names}, @named;
		$str .= sprintf('local %%_; { use warnings FATAL => qw(all); Data::Alias::alias(%%_ = @_[ %d .. $#_ ]) };', 1 + $self->last_position).qq[];
		unless (@slurpy or $self->yadayada)
		{
			$str .= sprintf('{ my %%OK = (%s); ', join q[,], map sprintf('%s=>1,', B::perlstring $_), @allowed_names);
			$str .= '$OK{$_}||Carp::croak("Unknown named parameter: $_") for sort keys %_ };';
		}
	}
	
	$str .= join qq[], map($_->injection($self), @named), q[];
	
	if (@slurpy > 1)
	{
		die "Too much slurping!";
	}
	elsif (@slurpy)
	{
		$str .= $slurpy[0]->injection($self);
	}
	
	return "$str; ();";
}

sub named_params
{
	my $self = shift;
	grep $_->named, @{$self->params};
}

sub positional_params
{
	my $self = shift;
	grep !$_->named && !$_->invocant && !$_->slurpy, @{$self->params};
}

sub slurpy_param
{
	my $self = shift;
	my ($s) = grep $_->slurpy, @{$self->params};
	$s;
}

sub invocants
{
	my $self = shift;
	grep $_->invocant, @{$self->params};
}

1;

__END__

=pod

=encoding utf-8

=for stopwords invocant invocants lexicals unintuitive yadayada

=head1 NAME

Kavorka::Signature - a function signature

=head1 DESCRIPTION

Kavorka::Signature is a class where each instance represents a function
signature. This class is used to parse the function signature, and also
to inject Perl code into the final function.

Instances of this class are also returned by Kavorka's function
introspection API.

=head2 Introspection API

A signature instance has the following methods. Each method
which returns parameters, returns an instance of
L<Kavorka::Signature::Parameter>.

=over

=item C<package>

Returns the package name the parameter was declared in.

=item C<params>

Returns an arrayref of parameters.

=item C<has_invocants>, C<invocants>

Returns a boolean/list of invocant parameters.

=item C<positional_params>

Returns a list of positional parameters.

=item C<has_named>, C<named_params>

Returns a boolean/list of named parameters.

=item C<has_slurpy>, C<slurpy>

Returns a boolean indicating whether there is a slurpy parameter
in this signature / returns the slurpy parameter.

=item C<yadayada>

Indicates whether the yadayada operator was encountered in the
signature.

=item C<last_position>

The numeric index of the last positional parameter.

=back

=head2 Other Methods

=over

=item C<parse>

An internal method used to parse a signature. Only makes sense to use
within a L<Parse::Keyword> parser.

=item C<parameter_class>

A class to use for parameters when parsing the signature.

=item C<injection>

The string of Perl code to inject for this signature.

=item C<sanity_check>

Tests that the signature is sane. (For example it would not be sane to
have a slurpy parameter prior to a positional one.)

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Kavorka>.

=head1 SEE ALSO

L<http://perlcabal.org/syn/S06.html>,
L<Kavorka>,
L<Kavorka::Signature::Parameter>.

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

