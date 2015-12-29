#!/usr/bin/perl -w
# photo-rename.pl
#
# Renames photos according to a template
#
# (c) David Haworth

#my $fn_template = "\$(FILE_DIR)\$(EXIF_YEAR)-\$(EXIF_MONTH)-\$(EXIF_DAY)-\$(FILE_SEQUENCE).\$(FILE_EXTENSION)";
#$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-N-$(FILE_SEQUENCE).$(FILE_EXTENSION)";
#$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-O-$(FILE_SEQUENCE).$(FILE_EXTENSION)";
#$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-M-$(FILE_SEQUENCE).$(FILE_EXTENSION)";

sub load_meta;
sub make_name;

my $fn_template = $ARGV[0];

if ( !defined $fn_template || $fn_template eq '-h' )
{
	print "photo-rename.pl -n [file ...]\n";
	print "photo-rename.pl -o [file ...]\n";
	print "photo-rename.pl -m [file ...]\n";
	print "photo-rename.pl TEMPLATE [file ...]\n";
	print "photo-rename.pl -h\n";
	exit(0);
}

if ( $fn_template eq '-n' )
{
	$fn_template = '$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-N-$(FILE_SEQUENCE).$(FILE_EXTENSION)';
}
elsif ( $fn_template eq '-o' )
{
	$fn_template = '$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-O-$(FILE_SEQUENCE).$(FILE_EXTENSION)';
}
elsif ( $fn_template eq '-m' )
{
	$fn_template = '$(FILE_DIR)$(EXIF_YEAR)-$(EXIF_MONTH)-$(EXIF_DAY)-M-$(FILE_SEQUENCE).$(FILE_EXTENSION)';
}

print "Template: $fn_template\n";

my $i = 1;

while ( defined $ARGV[$i] )
{
	my $oldname = $ARGV[$i];
	my %meta = load_meta($ARGV[$i]);
	my $newname = make_name($fn_template, %meta);

	if ( $newname eq "" || $newname eq $oldname || -e $newname )
	{
	}
	else
	{
		print STDERR "$oldname --> $newname\n";

		rename($oldname, $newname);
	}

	$i++;
}

exit 0;

# load_meta()
#
# Create a hashload of metadata out of the filename and the EXIF data.
sub load_meta
{
	my ($fn) = @_;

	my %meta = ();
	my ($fn_dir, $fn_base, $fn_name, $fn_ext, $fn_seq);

	if ( $fn =~ m{/} )
	{
		($fn_dir, $fn_name) = $fn =~ m{^(.*)/([^/]+)$};
	}
	else
	{
		$fn_dir = "";
		$fn_name = $fn;
	}

	if ( $fn_name =~ m{.\..} )
	{
		($fn_base, $fn_ext) = $fn_name =~ m{^(.*)\.([^\.]+)$};
	}
	else
	{
		$fn_base = $fn_name;
		$fn_ext = "";
	}

	($fn_seq) = $fn_base =~ m{(\d\d\d\d)\D*$};

	$fn_seq = "" if ( !defined $fn_seq );

	$fn_dir .= "/" if ( $fn_dir ne "" );

	$meta{"FILE_DIR"} = $fn_dir;
	$meta{"FILE_FULLNAME"} = $fn_name;
	$meta{"FILE_NAME"} = $fn_base;
	$meta{"FILE_EXTENSION"} = $fn_ext;
	$meta{"FILE_SEQUENCE"} = $fn_seq;

	open($exif_stream, "exiv2 $fn|");

	while ( <$exif_stream> )
	{
		chomp;
		my $exiv_line = $_;

		if ( $exiv_line ne "" )
		{
			my ($token, $value) = $exiv_line =~ m{^([^:]+):(.*)$};
			$token = Trim($token);
			$value = Trim($value);

			if ( defined $meta{$token} )
			{
				print STDERR "Duplicate EXIF token $token found.";
				print STDERR " Original value \"$meta{$token}\", new value \"$token\" ignored.\n";
			}
			else
			{
				$meta{$token} = $value;
			}
		}
	}

	close($exif_stream);

	if ( defined $meta{"Image timestamp"} )
	{
		my $timestamp = $meta{"Image timestamp"};
		my ($e_date,$e_time) = $timestamp =~ m{^(\S+)\s+(\S+)$};
		if ( defined $e_date )
		{
			if ( defined $e_time )
			{
				my ($e_year,$e_month,$e_day) = $e_date =~ m{^([^:]+):([^:]+):([^:]+)$};

				if ( defined $e_year && defined $e_month && defined $e_day )
				{
					$meta{"EXIF_YEAR"} = $e_year;
					$meta{"EXIF_MONTH"} = $e_month;
					$meta{"EXIF_DAY"} = $e_day;
				}
				else
				{
					print STDERR "Malformed date field \"$e_date\" in EXIF timestamp for $fn\n";
				}

				my ($e_hour,$e_minute,$e_second) = $e_time =~ m{^([^:]+):([^:]+):([^:]+)$};

				if ( defined $e_hour && defined $e_minute && defined $e_second )
				{
					$meta{"EXIF_HOUR"} = $e_hour;
					$meta{"EXIF_MINUTE"} = $e_minute;
					$meta{"EXIF_SECOND"} = $e_second;
				}
				else
				{
					print STDERR "Malformed date field \"$e_date\" in EXIF timestamp for $fn\n";
				}
			}
			else
			{
				print STDERR "Malformed image timestamp \"$timestamp\" in EXIF data for $fn\n";
			}
		}
		else
		{
			print STDERR "Malformed image timestamp \"$timestamp\" in EXIF data for $fn\n";
		}
	}
	else
	{
		print STDERR "No image timestamp in EXIF data for $fn\n";
	}

	my ($tk);

	foreach $tk (sort keys %meta)
	{
#		print STDERR "meta{$tk} = \"$meta{$tk}\"\n";
	}

	return %meta
}

# make_name()
#
# Make a filename by filling the template with the metadata
sub make_name
{
	my ($new_fn, %meta) = @_;
	my $working = 1;

	while ( $working )
	{
		my ($key) = $new_fn =~ m{\$\(([^\)]+)\)};

		if ( defined $key )
		{
#			print STDERR "key: \"$key\"\n";

			if ( defined $meta{$key} )
			{
				$new_fn =~ s/\$\([^\)]+\)/$meta{$key}/;
			}
			else
			{
				$new_fn = "";
				$working = 0;
			}
		}
		else
		{
			$working = 0;
		}
	}

#	print STDERR "make_name: \"$new_fn\"\n";

	return $new_fn;
}


# Trim()
#
# Trims leading and trailing spaces from string.
# Returns result.
sub Trim
{
    my ($txt) = @_;

	if ( defined $txt )
	{
	    $txt =~ s/^\s+(\S.*)$/$1/;
	    $txt =~ s/^(.*\S)\s+$/$1/;
		$txt =~ s/^\s+$//;
	}
	else
	{
		$txt = "";
	}
    return $txt;
}
