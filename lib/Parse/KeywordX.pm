use 5.014;
use strict;
use warnings;

use Exporter::Tiny ();

package Parse::KeywordX;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.004';

use Parse::Keyword {};

our @ISA    = qw( Exporter::Tiny );
our @EXPORT = qw( parse_name );

#### From p5-mop-redux
sub read_tokenish ()
{
	my $token = '';
	if ((my $next = lex_peek) =~ /[\$\@\%]/)
	{
		$token .= $next;
		lex_read;
	}
	while ((my $next = lex_peek) =~ /\S/)
	{
		$token .= $next;
		lex_read;
		last if ($next . lex_peek) =~ /^\S\b/;
	}
	return $token;
}

#### From p5-mop-redux
sub parse_name
{
	my ($what, $allow_package) = @_;
	my $name = '';

	# XXX this isn't quite right, i think, but probably close enough for now?
	my $start_rx = qr/^[\p{ID_Start}_]$/;
	my $cont_rx  = qr/^\p{ID_Continue}$/;
	my $char_rx = $start_rx;

	while (1)
	{
		my $char = lex_peek;
	
		last unless length $char;
		if ($char =~ $char_rx)
		{
			$name .= $char;
			lex_read;
			$char_rx = $cont_rx;
		}
		elsif ($allow_package && $char eq ':')
		{
			die("Invalid identifier: $name" . read_tokenish)
				unless lex_peek(3) =~ /^::(?:[^:]|$)/;
			$name .= '::';
			lex_read(2);
		}
		else
		{
			last;
		}
	}

	die("Not a valid $what name: " . read_tokenish) unless length $name;
	
	($name =~ /\A::/) ? "main$name" : $name;
}

1;
