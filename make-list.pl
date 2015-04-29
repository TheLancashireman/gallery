#!/usr/bin/perl -w
# make-list.pl
#
# Makes a collapsible list of things from a CSV file.
#
# (c) David Haworth

use Template;

sub Trim;

my $list_title = "Dave's books";
my $list_header = "Dave's books";
my $list_subject = "Fiction by author";

my $csvname = $ARGV[0];
my $htmlname = $ARGV[1];
my $template = "x-list-html.tmpl";
my $templatedir = "/data/family-history/tools/gallery/templates";
my $csvfile;
my $DBG = 0;

die "Usage: make-list.pl <CSV-file> <HTML-file>\n" if ( !defined $csvname );
open($csvfile, "<$csvname") or die "Could not open $csvname for reading\n";

my @n_authors_per_initial = ();
my @n_books_per_author = ();
my @initials = ();
my @authors = ();
my @authorids = ();
my @books = ();
my @bookids = ();

my $last_initial = "XXX";
my $last_author = "XXX";
my $n_initial = 0;			# No. of initials
my $n_author = 0;			# Total no. of authors
my $n_author_initial = 0;	# No. of authors with current initial
my $n_book = 0;				# Totla no. of books (actually, no. of entries)
my $n_book_author = 0;		# No of books with current author

# Instance of the template stuff
my $tt = Template->new({
    INCLUDE_PATH => $templatedir,
    INTERPOLATE => 0,
}) || die "$Template::ERROR\n";

while ( <$csvfile> )
{
	chomp;
	my $line = $_;

	my ($surname, $forenames, $title, $a_comment, $t_comment) = split /\|/, $line;

	$surname = Trim($surname);
	$forenames = Trim($forenames);
	$title = Trim($title);
	$a_comment = Trim($a_comment);
	$t_comment = Trim($t_comment);

	# Construct full author's name
	my $author = "$forenames $surname";

	if ( $author ne $last_author )
	{
		($initial) = $surname =~ m{^(.)};

		if ( $initial ne $last_initial )
		{
			# Store the number of authors with the previous initial, if there was one
			$n_authors_per_initial[$n_initial-1] = $n_author_initial if ( $n_initial > 0 );

			# Change of initial. Store the initial.
			$initials[$n_initial] = $initial;
			$n_initial++;

			print STDOUT "INITIAL: $initial\n" if ( $DBG > 0 );

			# Start counting the authors with the new initial.
			$last_initial = $initial;
			$n_author_initial = 0;
		}

		# Store the number of books by the previous author if there was one
		$n_books_per_author[$n_author-1] = $n_book_author if ( $n_author > 0 );

		# Change of author. Store the author
		$authors[$n_author] = $author;
		$authorids[$n_author] = $author;
		$authorids[$n_author] =~ s/\s//g;
		$n_author++;
		$n_author_initial++;

		print STDOUT "  AUTHOR: $author\n" if ( $DBG > 0 );

		# Start counting the books by the new author
		$last_author = $author;
		$n_book_author = 0;
	}

	# Construct book name from title and title comment if present. Store in list.
	$books[$n_book] = $title;
	$books[$n_book] .= " ($a_comment)" if ( defined $a_comment && $a_comment ne "" );
	$books[$n_book] .= " ($t_comment)" if ( defined $t_comment && $t_comment ne "" );
	$bookids[$n_book] = $title;
	$bookids[$n_book] =~ s/\s//g;
	$n_book++;
	$n_book_author++;

	print STDOUT "    TITLE: $title TC: \"$t_comment\" AC: \"$a_comment\"\n" if ( $DBG > 0 );
}

close($csvfile);

$n_authors_per_initial[$n_initial-1] = $n_author_initial if ( $n_initial > 0 );
$n_books_per_author[$n_author-1] = $n_book_author if ( $n_author > 0 );

my $list_vars =
{
	list_title		=> $list_title,
	list_header		=> $list_header,
	list_subject	=> $list_subject,
	n_initials		=> $n_initial,
	n_authors		=> \@n_authors_per_initial,
	n_books			=> \@n_books_per_author,
	initials		=> \@initials,
	authors			=> \@authors,
	authorids		=> \@authorids,
	books			=> \@books,
	bookids			=> \@bookids
};

if ( $tt->process($template, $list_vars, $htmlname) )
{
}
else
{
	print STDERR "Template generation failed: " . $tt->error() . "\n";
}

exit 0;

# Trim()
#
# Trims leading and trailing spaces from string.
# Returns result.
sub Trim
{
    my ($txt) = @_;
    $txt =~ s/^\s*(\S.*)$/$1/;
    $txt =~ s/^(.*\S)\s*$/$1/;
    return $txt;
}
