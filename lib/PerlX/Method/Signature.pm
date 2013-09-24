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
has parameters      => (is => 'rwp', default => sub { +[] });
has has_invocants   => (is => 'rwp', default => sub { +undef });
has parameter_class => (is => 'ro',  default => sub { 'PerlX::Method::Signature::Parameter' });

sub parse
{
	my $class = shift;
	my ($str, %args) = @_;
	
	# PPI genuinely seems to be the best solution here.
	my $doc = 'PPI::Document'->new(\$str);
	my $st  = $doc->find_first('PPI::Statement');
	
	#require PPI::Dumper; PPI::Dumper->new($st)->print;
	
	my $saw_invocant;
	my $last_token;
	my @arr;
	for my $tok ($st->children)
	{
		@arr = '' unless @arr;
		
		if ($tok->isa('PPI::Token::Symbol') and $tok eq '$,')
		{
			$arr[-1] .= '$';
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
	
	my $self = $class->new(%args, as_string => $_[0]);
	$self->_set_parameters([
		map $self->parameter_class->parse($_, $self),
		map s/(\A\s+)|(\s+\z)//rgsm,
		@arr
	]);
	$self->sanity_check;
	return $self;
}

sub sanity_check
{
	my $self = shift;
	
	my $has_invocants = 0;
	for my $p (reverse @{ $self->parameters or die })
	{
		if ($p->is_invocant) {
			$has_invocants++;
			next;
		}
		elsif ($has_invocants) {
			$has_invocants++;
			$p->_set_is_invocant(1);  # anything prior to an invocant is also an invocant!
		}
	}
	$self->_set_has_invocants($has_invocants);
	
	my $i = 0;
	for my $p (@{ $self->parameters or die })
	{
		next if $p->is_invocant;
		last if $p->is_slurpy;
		last if $p->{traits}{slurpy};
		$p->_set_position($i++);
	}
}

sub injections
{
	my $self = shift;
	return join("\n", map $_->injection, @{$self->parameters}) . "\n();\n";
}

1;
