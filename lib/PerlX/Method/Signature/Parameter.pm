use 5.014;
use strict;
use warnings;

package PerlX::Method::Signature::Parameter;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001';

use Text::Balanced qw( extract_codeblock extract_bracketed );

use Moo;

has type            => (is => 'ro');
has name            => (is => 'ro');
has constraints     => (is => 'ro', default => sub { +[] });
has named           => (is => 'ro', default => sub { 0 });
has named_names     => (is => 'ro', default => sub { +[] });

has as_string       => (is => 'ro');
has position        => (is => 'rwp');
has default         => (is => 'ro');
has ID              => (is => 'rwp');
has traits          => (is => 'ro', default => sub { +{} });

sub readonly  { +die }
sub rw        { +die }
sub copy      { +die }
sub slurpy    { !!shift->traits->{slurpy} }
sub optional  { !!shift->traits->{optional} }
sub invocant  { !!shift->traits->{invocant} }
sub coerce    { !!shift->traits->{coerce} }

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
	
	my ($named, $varname, $paramname) = 0;
	my %traits = (
		invocant  => 0,
		optional  => 1,
	);
	
	if ($rest =~ /\A(\:(\w+)\(\s*([\$\%\@]\w*)\s*\))/)
	{
		$named     = 1;
		$paramname = $2;
		$varname   = $3;
		substr($rest, 0, length($1), '');
	}
	elsif ($rest =~ /\A(\:([\$\%\@]\w*))/)
	{
		$named     = 1;
		$paramname = substr($2, 1);
		$varname   = $2;
		substr($rest, 0, length($1), '');
	}
	elsif ($rest =~ /\A([\$\%\@]\w*)/)
	{
		$varname   = $1;
		$traits{optional} = 0;
		substr($rest, 0, length($1), '');
	}
	
	$rest =~ s/\A\s+//;
	
	$traits{is_slurpy} = 0+!!( $varname !~ /\A\$/ );
	
	if ($rest =~ /\A\:/)
	{
		$traits{optional} = 0;
		$traits{invocant} = 1;
		substr($rest, 0, 1, '');
	}
	elsif ($rest =~ /\A\!/)
	{
		$traits{optional} = 0;
		substr($rest, 0, 1, '');
	}
	elsif ($rest =~ /\A\?/)
	{
		$traits{optional} = 1;
		substr($rest, 0, 1, '');
	}
	
	$rest =~ s/\A\s+//;
	
	my (@constraints, $default);
	
	while ($rest =~ /\Awhere/)
	{
		substr($rest, 0, 5, '');
		my $constraint = extract_codeblock($rest, '(){}[]<>', undef, '{}') or die;
		$constraint =~ s/\A\s*\{//;
		$constraint =~ s/}\s*\z//;
		push @constraints, $constraint;
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
		name           => $varname,
		constraints    => \@constraints,
		named          => $named,
		named_names    => [ $paramname ],
		default        => $default,
		traits         => \%traits,
	);
}

### XXX - additional constraints
### XXX - slurpy arguments
### XXX - required versus optional

sub injection
{
	my $self = shift;
	
	my $var = $self->name;
	my $dummy = 0;
	if ($var eq '$')
	{
		$var = '$tmp';
		$dummy = 1;
	}
	
	my $condition;
	my $val;
	my $default = $self->default;
	
	if ($self->slurpy)
	{
		return '"SLURPY"'; # TODO
	}
	elsif ($self->named)
	{
		my $defaultish = $default;
		$defaultish = $self->optional ? 'undef' : 'die()' unless length $defaultish;
		$val = join '', map(
			sprintf('exists($_{%s}) ? $_{%s} : ', $_, $_),
			map B::perlstring($_), @{$self->named_names}
		), $defaultish;
		$condition = join ' or ', map(
			sprintf('exists($_{%s})', $_),
			map B::perlstring($_), @{$self->named_names}
		);
	}
	else
	{
		$val = $self->invocant
			? 'shift(@_)'
			: sprintf('$_[%d]', $self->position);
		$val = sprintf('$#_ < %d ? (%s) : %s', $self->position, $default, $val)
			if length $default;
		
		$condition = $self->invocant ? 1 : sprintf('$#_ < %d', $self->position);
	}
	
	$condition = 1 if length $default;
	
	my $ass = sprintf(
		'%s %s = %s;',
		($var eq '$_' || $var eq '$.' ? 'local' : 'my'),
		$var,
		$val,
	);
	
	my $type = $condition eq '1'
		? sprintf('%s;', $self->_inject_type_check($var))
		: sprintf('if (%s) { %s }', $condition, $self->_inject_type_check($var));
	
	$dummy ? "{ $ass; $type }" : "{ $ass; $type }";
}

sub _inject_type_check
{
	my $self = shift;
	my ($var) = @_;
	
	my $check = '';
	return $check unless my $type = $self->type;
	
	if ($self->coerce and $type->has_coercion)
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
