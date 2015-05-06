#!/usr/bin/perl -w
# make-list.pl
#
# Makes a collapsible list of things from a CSV file.
#
# (c) David Haworth

use Template;

sub Trim;
sub TxtToId;

my $list_title = "Dave's stuff";
my $list_header = "Dave's stuff";
my $list_subject = "Stuff";

my $csvname = $ARGV[0];
my $htmlname = $ARGV[1];
my $template = "x-list-html.tmpl";
my $templatedir = "/data/family-history/tools/gallery/templates";
my $csvfile;
my $DBG = 0;
my $list_type = "?";

die "Usage: make-list.pl <CSV-file> <HTML-file>\n" if ( !defined $csvname );
open($csvfile, "<$csvname") or die "Could not open $csvname for reading\n";

if ( $csvname =~ m{nonfiction} )
{
	$list_type = "nonfiction";
	$list_title = "Dave's books";
	$list_header = "Dave's books";
	$list_subject = "Non-fiction by author (under construction)";
}
elsif ( $csvname =~ m{fiction} )
{
	$list_type = "fiction";
	$list_title = "Dave's books";
	$list_header = "Dave's books";
	$list_subject = "Fiction by author";
}

my %columns = ();

my @n_authors_per_initial = ();
my @n_books_per_author = ();
my @initials = ();
my @authors = ();
my @authorids = ();
my @books = ();
my @bookids = ();
my @a_comments = ();
my @b_comments = ();
my @a_urls = ();
my @b_urls = ();

my $line_no = 0;
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

	my @fields = split /\|/, $line;

	if ( $line_no == 0 )
	{
		my $fno = 0;
		my $fld;

		foreach $fld ( @fields )
		{
			$columns{$fld} = $fno;
			$fno++;
		}

		if ( defined $columns{"a_surname"} &&
			 defined $columns{"a_forename"} &&
			 defined $columns{"b_title"} &&
			 defined $columns{"a_comment"} &&
			 defined $columns{"b_comment"} &&
			 defined $columns{"dh_class"} &&
			 defined $columns{"a_url"} &&
			 defined $columns{"b_url"} )
		{
			# All expected columns are present
		}
		else
		{
			print STDERR "One or more expected columns missing.\n";
			print STDERR "Expect: a_surname, a_forename, b_title, a_comment, b_comment, dh_class, a_url, b_url\n";
			print STDERR "Got: $line\n";
			exit(1);
		}
		
		$line_no = 1;
	}
	else
	{
		my $surname			= Trim($fields[$columns{"a_surname"}]);
		my $forenames		= Trim($fields[$columns{"a_forename"}]);
		my $title			= Trim($fields[$columns{"b_title"}]);
		my $a_comment		= Trim($fields[$columns{"a_comment"}]);
		my $t_comment		= Trim($fields[$columns{"b_comment"}]);
		my $classification	= Trim($fields[$columns{"dh_class"}]);
		my $a_url			= Trim($fields[$columns{"a_url"}]);
		my $t_url			= Trim($fields[$columns{"b_url"}]);

		# Construct full author's name
		my $author = "$forenames $surname";

		if ( $author ne $last_author )
		{
			($initial) = $surname =~ m{^(.)};
			$initial = uc($initial);

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
			$authorids[$n_author] = TxtToId($author);
			$a_urls[$n_author] = $a_url;
			$n_author++;
			$n_author_initial++;

			print STDOUT "  AUTHOR: $author, URL=\"$a_url\"\n" if ( $DBG > 0 );

			# Start counting the books by the new author
			$last_author = $author;
			$n_book_author = 0;
		}

		if ( $a_url ne "" )
		{
			if ( $a_urls[$n_author-1] eq "" )
			{
				$a_urls[$n_author-1] = $a_url;
			}
			else
			{
				if ( $a_urls[$n_author-1] ne $a_url )
				{
					print STDERR "WARNING: Conflicting URL \"$a_url\" found for $authors[$n_author-1]\n";
				}
			}
		}


		# Construct book name from title and title comment if present. Store in list.
		$books[$n_book] = $title;
		$a_comments[$n_book] = $a_comment;
		$t_comments[$n_book] = $t_comment;
		$t_urls[$n_book] = $t_url;
		$t_class[$n_book] = $classification;
		$bookids[$n_book] = TxtToId($title);
		$n_book++;
		$n_book_author++;

		print STDOUT "    TITLE: $title TC: \"$t_comment\" AC: \"$a_comment\"\n" if ( $DBG > 0 );
		$line_no++;
	}
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
	bookids			=> \@bookids,
	a_comments		=> \@a_comments,
	a_urls			=> \@a_urls,
	t_comments		=> \@t_comments,
	t_urls			=> \@t_urls,
	t_class			=> \@t_class,
	list_type		=> $list_type
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

	if ( defined $txt )
	{
	    $txt =~ s/^\s*(\S.*)$/$1/;
	    $txt =~ s/^(.*\S)\s*$/$1/;
	}
	else
	{
		$txt = "";
	}
    return $txt;
}

# TxtToId()
#
# Remmoves all non-alphanumeric characters
sub TxtToId
{
	my ($txt) = @_;

	$txt =~ s/[^A-Za-z0-9]//g;
	return $txt;
}
