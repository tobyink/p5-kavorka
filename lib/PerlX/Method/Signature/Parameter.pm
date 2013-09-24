use 5.014;
use strict;
use warnings;

package PerlX::Method::Signature::Parameter;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Text::Balanced qw( extract_codeblock extract_bracketed );

use Moo;

has as_string       => (is => 'ro');
has variable_name   => (is => 'ro');
has parameter_name  => (is => 'ro');
has position        => (is => 'rwp');
has is_invocant     => (is => 'rwp');
has is_positional   => (is => 'ro');
has is_required     => (is => 'ro');
has is_slurpy       => (is => 'ro');
has type            => (is => 'ro');
has constraint      => (is => 'ro');
has traits          => (is => 'ro');
has default         => (is => 'ro');
has ID              => (is => 'rwp');

our @PARAMS;
sub BUILD
{
	my $self = shift;
	my $id = scalar(@PARAMS);
	$self->_set_ID($id);
	$PARAMS[$id] = $self;
}

sub parse
{
	my $class = shift;
	my ($str, $sig, %args) = @_;
	
	$str =~ s/\A\s+//;
	
	my ($type, $rest);
	if ($str =~ /\A[^\W0-9]/)
	{
		$sig->{registry} ||= do {
			require Type::Registry;
			require Type::Utils;
			my $tmp = 'Type::Registry::DWIM'->new;
			$tmp->{'~~chained'} = $sig->{package};
			$tmp->{'~~assume'}  = 'Type::Tiny::Class';
			$tmp;
		};
		
		require Type::Parser;
		($type, $rest) = Type::Parser::extract_type($str, $sig->{registry});
		$rest =~ s/\A\s+//;
	}
	else
	{
		($type, $rest) = (undef, $str);
	}
	
	my ($is_invocant, $is_positional, $is_required, $varname, $paramname) = (0, 0, 0);
	
	if ($rest =~ /\A(\:(\w+)\(\s*([\$\%\@]\w*)\s*\))/)
	{
		$paramname = $2;
		$varname   = $3;
		substr($rest, 0, length($1), '');
	}
	elsif ($rest =~ /\A(\:([\$\%\@]\w*))/)
	{
		$paramname = substr($2, 1);
		$varname   = $2;
		substr($rest, 0, length($1), '');
	}
	elsif ($rest =~ /\A([\$\%\@]\w*)/)
	{
		$varname   = $1;
		substr($rest, 0, length($1), '');
		$is_positional = 1;
		$is_required = 1;
	}
	
	$rest =~ s/\A\s+//;
	
	if ($rest =~ /\A\:/)
	{
		$is_invocant = 1;
		$is_required = 1;
		substr($rest, 0, 1, '');
	}
	elsif ($rest =~ /\A\!/)
	{
		$is_required = 1;
		substr($rest, 0, 1, '');
	}
	elsif ($rest =~ /\A\?/)
	{
		$is_required = 0;
		substr($rest, 0, 1, '');
	}
	
	$rest =~ s/\A\s+//;
	
	my ($constraint, $default, %traits);
	
	if ($rest =~ /\Awhere/)
	{
		substr($rest, 0, 5, '');
		$constraint = extract_codeblock($rest, '(){}[]<>', undef, '{}') or die;
		$constraint =~ s/\A\s*\{//;
		$constraint =~ s/}\s*\z//;
		$rest =~ s/\A\s+//;
	}
	
	while ($rest =~ /\A((?:is|does)\s+(\w+))/sm)
	{
		$traits{"$2"} = 1;
		substr($rest, 0, length($1), '');
		$rest =~ s/\A\s+//;
	}
	
	if ($rest =~ m{\A(//)?=})
	{
		$rest =~ s{\A(//)?=}{};
		$default = $rest;
		$rest = '';
	}
	
	die if length $rest;
	
	return $class->new(
		%args,
		as_string      => $_[0],
		type           => $type,
		variable_name  => $varname,
		parameter_name => $paramname,
		is_invocant    => $is_invocant,
		is_positional  => $is_positional,
		is_required    => $is_required,
		default        => $default,
		constraint     => $constraint,
		traits         => \%traits,
		is_slurpy      => 0+!!( $varname !~ /\A\$/ ),
	);
}

sub injection
{
	my $self = shift;
	my ($ass, $var, $is_dummy) = $self->_inject_assignment;
	my $types = $self->_inject_type_check($var);
	$is_dummy ? "{ $ass $types };" : "$ass $types";
}

sub _inject_assignment
{
	my $self = shift;
	
	my $var = $self->variable_name;
	my $dummy = 0;
	if ($var eq '$')
	{
		$var = '$tmp';
		$dummy = 1;
	}
	
	my $val = $self->is_invocant
		? 'shift(@_)'
		: sprintf('$_[%d]', $self->position);
	
	if (length(my $default = $self->default))
	{
		$val = sprintf('$#_ < %d ? (%s) : %s', $self->position, $default, $val);
	}
	
	my $ass = sprintf(
		'%s %s = %s;',
		($var eq '$_' || $var eq '$.' ? 'local' : 'my'),
		$var,
		$val,
	);
	
	return ($ass, $var, $dummy);
}

sub _inject_type_check
{
	my $self = shift;
	my ($var) = @_;
	
	my $check = '';
	return $check unless my $type = $self->type;
	
	if ($self->traits->{coerce} and $type->has_coercion)
	{
		if ($type->coercion->can_be_inlined)
		{
			$check .= sprintf(
				'%s = %s;',
				$var,
				$type->coercion->inline_coercion($var),
			);
		}
		else
		{
			$check .= sprintf(
				'%s = %s::PARAMS[%d]->type->coerce(%s);',
				$var,
				__PACKAGE__,
				$self->ID,
				$var,
			);
		}
	}		
	
	if ($type->can_be_inlined)
	{
		$check .= sprintf(
			'%s;',
			$type->inline_assert($var),
		);
	}
	else
	{
		$check .= sprintf(
			'%s::PARAMS[%d]->assert_valid(%s);',
			__PACKAGE__,
			$self->ID,
			$var,
		);
	}
	
	return $check;
}


1;
