use v5.14;
use strict;
use warnings;
use Time::Limit '5';

BEGIN {
	package PerlX::Method::Signature::Parameter;
	
	use Class::Tiny qw(
		as_string variable_name parameter_name position
		is_invocant is_positional is_required is_slurpy
		type constraint traits default ID
	);
	use Text::Balanced qw( extract_codeblock extract_bracketed );
	
	our @PARAMS;
	sub BUILD
	{
		my $self = shift;
		my $id = scalar(@PARAMS);
		$self->ID($id);
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
};

BEGIN {
	package PerlX::Method::Signature;
	
	use Class::Tiny qw( as_string parameters package has_invocants );
	use PPI::Document qw();
	
	sub parameter_class { 'PerlX::Method::Signature::Parameter' };
	
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
		$self->parameters([
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
				$p->is_invocant(1);  # anything prior to an invocant is also an invocant!
			}
		}
		$self->has_invocants($has_invocants);
		
		my $i = 0;
		for my $p (@{ $self->parameters or die })
		{
			next if $p->is_invocant;
			last if $p->is_slurpy;
			last if $p->{traits}{slurpy};
			$p->position($i++);
		}
	}
	
	sub injections
	{
		my $self = shift;
		return join("\n", map $_->injection, @{$self->parameters}) . "\n();\n";
	}
};

BEGIN {
	package PerlX::Method;
	
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
	
	sub signature_class { 'PerlX::Method::Signature' };
	
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
};

no thanks 'PerlX::Method';
use PerlX::Method;

method bar ($self : Int $x where { $_ % 2 == 0 }, $y = foo(1,2), $, :www($w), ArrayRef[Str] :$z? is foo is bar = [qw/Hello world/]) : ($;@) {
	say $_[0];
}

__PACKAGE__->bar(123, "hiya");
