use 5.014;
use strict;
use warnings;

use PPI::Document ();
use PerlX::Method::Signature::Parameter ();

package PerlX::Method::Signature;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Moo;

has package         => (is => 'ro');
has as_string       => (is => 'ro');
has params          => (is => 'rwp', default => sub { +[] });
has has_invocants   => (is => 'rwp', default => sub { +undef });
has has_named       => (is => 'rwp', default => sub { +undef });
has has_slurpy      => (is => 'rwp', default => sub { +undef });
has yadayada        => (is => 'rwp', default => sub { 0 });
has parameter_class => (is => 'ro',  default => sub { 'PerlX::Method::Signature::Parameter' });
has last_position   => (is => 'lazy');

sub parse
{
	my $class = shift;
	my ($str, %args) = @_;
	
	# PPI genuinely seems to be the best solution here.
	my $doc = 'PPI::Document'->new(\$str);
	my $st  = $doc->find_first('PPI::Statement');
	#require PPI::Dumper; PPI::Dumper->new($st)->print;
	my @tokens = $st ? $st->children : ();
	
	my $saw_invocant;
	my $last_token;
	my @arr;
	for my $tok (@tokens)
	{
		next if $tok->isa('PPI::Token::Comment');
		
		@arr = '' unless @arr;
		
		if ($tok->isa('PPI::Token::Symbol') and $tok eq '$,')
		{
			$arr[-1] .= '$';
			push @arr, '';
			next;
		}

		if ($tok->isa('PPI::Token::Symbol') and $tok eq '$:' and not $saw_invocant)
		{
			$saw_invocant++;
			$arr[-1] .= '$ :';
			push @arr, '';
			next;
		}

		if ($tok->isa('PPI::Token::Operator') and $tok eq ',')
		{
			push @arr, '';
			next;
		}
		
		if ($tok->isa('PPI::Token::Operator')
		and $tok eq ':'
		and $last_token->isa('PPI::Token::Symbol')
		and $last_token =~ /\A\$/
		and not $saw_invocant)
		{
			$saw_invocant++;
			
			$arr[-1] .= $tok;
			push @arr, '';
			next;
		}
		
		$arr[-1] .= $tok;
		$last_token = $tok unless $tok->isa('PPI::Token::Whitespace');
	}
	
	# canonicalize
	@arr = map s/(\A\s+)|(\s+\z)//rgsm, grep /\S/, @arr;
		
	my $self = $class->new(%args, as_string => $_[0]);
	if (@arr and $arr[-1] =~ /\A\.{3,}\z/)
	{
		$self->_set_yadayada(1);
		pop(@arr);
	}
	$self->_set_params([map $self->parameter_class->parse($_, $self), @arr]);
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
	my ($last) = grep !$_->named && !$_->slurpy, reverse @{$self->params};
	return $last->position;
}

sub injections
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
	my @allowed_names = map +($_=>1), map @{$_->named_names}, @named;
	
	$str .= join qq[], map($_->injection($self), @positional), q[];
	if (@named)
	{
		$str .= sprintf('local %%_ = @_[ %d .. $#_ ];', 1 + $self->last_position).qq[];
		unless (@slurpy or $self->yadayada)
		{
			$str .= sprintf('{ my %%OK = (%s); ', map sprintf('%s=>1,', B::perlstring $_), @allowed_names);
			$str .= '$OK{$_}||die("Unknown named parameter: $_") for sort keys %_ };';
		}
	}
	elsif (not ($self->yadayada || @slurpy))
	{
		my $min = scalar(@req_positional);
		my $max = scalar(@req_positional) + scalar(@opt_positional);
		$str .= $min==$max
			? sprintf('die("Expected %d parameters") unless @_ == %d;', $min, $min)
			: sprintf('die("Expected between %d and %d parameters") unless @_ >= %d && @_ <= %d;', $min, $max, $min, $max);
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

1;
