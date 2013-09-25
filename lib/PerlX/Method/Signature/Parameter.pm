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
has default_when    => (is => 'ro');
has ID              => (is => 'rwp');
has traits          => (is => 'ro', default => sub { +{} });

sub readonly  { +die }
sub rw        { +die }
sub copy      { !!shift->traits->{alias} }
sub slurpy    { !!shift->traits->{slurpy} }
sub optional  { !!shift->traits->{optional} }
sub invocant  { !!shift->traits->{invocant} }
sub coerce    { !!shift->traits->{coerce} }

sub sigil     { substr(shift->name, 0, 1) }

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
	
	my %traits = (
		invocant  => 0,
		_optional => 1,
	);
	
	if ($str =~ /\A(slurpy\s+)/)
	{
		substr($str, 0, length($1), '');
		$traits{slurpy} = 1;
	}
	
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
		$traits{_optional} = 0;
		substr($rest, 0, length($1), '');
	}
	
	$rest =~ s/\A\s+//;
	
	$traits{slurpy} = 1 if $varname =~ /\A[\@\%]/;
	
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
	
	my (@constraints, $default, $default_when);
	
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
	
	if ($rest =~ m{\A((?://|\|\|)?=)})
	{
		$default_when = $1;
		substr($rest, 0, length($default_when), '');
		$default = $rest;
		$rest = '';
		$traits{_optional} = 1;
	}
	
	$traits{optional} //= $traits{_optional};
	delete($traits{_optional});
	
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
		default_when   => $default_when,
		traits         => \%traits,
	);
}

sub sanity_check
{
	my $self = shift;
	
	die if $self->invocant && $self->optional;
	die if $self->invocant && $self->named;
	die if $self->invocant && $self->slurpy;
	die if $self->optional && $self->slurpy;
	die if $self->named && $self->slurpy;
}

### XXX - an "alias" trait
### XXX - the @_ and %_ special slurpies
### XXX - the //= and ||= default types

sub injection
{
	my $self = shift;
	my ($sig) = @_;
	
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
	my $slurpy_style = '';
	
	if ($self->slurpy)
	{
		if ($self->sigil eq '%'
		or ($self->sigil eq '$'
			and $self->type
			and do { require Types::Standard; $self->type->is_a_type_of(Types::Standard::HashRef()) }))
		{
			$val = sprintf(
				'do { use warnings FATAL => qw(all); my %%tmp = @_[ %d .. $#_ ]; delete $tmp{$_} for (%s); %%tmp ? %%tmp : (%s) }',
				$sig->last_position + 1,
				join(
					q[,],
					map B::perlstring($_), map(@{$_->named ? $_->named_names : []}, @{$sig->params}),
				),
				($default // ''),
			);
			$condition = 1;
			$slurpy_style = '%';
		}
		else
		{
			die "Cannot have a slurpy array for a function with named parameters" if $sig->has_named;
			$val = sprintf(
				'($#_ > %d) ? @_[ %d .. $#_ ] : (%s)',
				$sig->last_position + 1,
				$sig->last_position + 1,
				($default // ''),
			);
			$condition = 1;
			$slurpy_style = '@';
		}
		
		if ($self->sigil eq '$')
		{
			$val = $slurpy_style eq '%' ? "+{ $val }" : "[ $val ]";
			$slurpy_style = '$';
		}
	}
	elsif ($self->named)
	{
		my $defaultish =
			length($default) ? $default :
			$self->optional  ? 'undef'  :
			sprintf('die(sprintf("Named parameter `%%s` is required", %s))', B::perlstring $self->named_names->[0]);
			
		$val = join '', map(
			sprintf('exists($_{%s}) ? $_{%s} : ', $_, $_),
			map B::perlstring($_), @{$self->named_names}
		), $defaultish;
		
		$condition = join ' or ', map(
			sprintf('exists($_{%s})', $_),
			map B::perlstring($_), @{$self->named_names}
		);
	}
	elsif ($self->invocant)
	{
		my $defaultish = sprintf('die(q/Invocant %s is required/)', $self->name);
		$val = sprintf('@_ ? shift(@_) : (%s)', $defaultish);
		$condition = 1;
	}
	else
	{
		my $pos        = $self->position;
		my $defaultish =
			length($default) ? $default :
			$self->optional  ? 'undef'  :
			sprintf('die("Positional parameter %d is required")', $pos);
		
		$val = sprintf('$#_ >= %d ? $_[%d] : (%s)', $pos, $pos, $defaultish);
		
		$condition = sprintf('$#_ >= %d', $self->position);
	}
	
	$condition = 1 if length $default;
	
	my $ass = sprintf(
		'%s %s = %s;',
		($var eq '$_' || $var eq '$.' ? 'local' : 'my'),
		$var,
		$val,
	);
	
	my $type = 
		($slurpy_style eq '@') ? sprintf('for ($var) { %s }', $condition, $self->_inject_type_check('$_')) :
		($slurpy_style eq '%') ? sprintf('for (values $var) { %s }', $condition, $self->_inject_type_check('$_')) :
		($condition eq '1')    ? sprintf('%s;', $self->_inject_type_check($var)) :
		sprintf('if (%s) { %s }', $condition, $self->_inject_type_check($var));
	
	$dummy ? "{ $ass$type }" : "$ass$type";
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
	
	for my $constraint (@{ $self->constraints })
	{
		$check .= sprintf(
			'do { local $_ = %s; %s } or die(sprintf("%%s failed constraint {%%s}", %s, %s));',
			$var,
			$constraint,
			B::perlstring($var),
			B::perlstring($constraint),
		);
	}
	
	return $check;
}


1;
