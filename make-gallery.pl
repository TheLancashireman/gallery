#!/usr/bin/perl -w
#
# make-gallery.pl - create a photo gallery
#
# (c) 2010 David Haworth
#
# This file is part of Dave's Gallery Tools.
#
# Dave's Gallery Tools is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Dave's Gallery Tools is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Dave's Gallery Tools.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id$

use Template;

sub Usage;
sub ReadGalleryFile;
sub ConstructGalleryVars;
sub WriteGalleryHtml;
sub Trim;

my $in_name = $ARGV[0];
my $out_name = $ARGV[1];
my $n_errors;
my $gallery_vars;
my $DBG = 0;
my $text_line_separator = "\n";
my $caption_line_separator = "\n";
my $subtext_line_separator = "\n";

# Data read from gallery file or constructed when not present
my $gallery_title;
my $gallery_header;
my $gallery_text;
my $gallery_filename;
my $n_images = 0;
my @images;
my @thumbs;
my @captions;
my @subtexts;

# Instance of the template stuff
my $tt = Template->new({
    INCLUDE_PATH => "/data/family-history/tools/gallery/templates",
    INTERPOLATE => 0,
}) || die "$Template::ERROR\n";

if ( -r $in_name )
{
}
else
{
	Usage($in_name." is not a readable file.");
}

if ( -d $out_name )
{
}
else
{
	Usage($out_name." is not a directory.");
}

$n_errors = ReadGalleryFile($in_name);

if ( $n_errors == 0 )
{
	my $html_name;
	($n_errors, $html_name, $gallery_vars) = ConstructGalleryVars();

	if ( $n_errors == 0 )
	{
		WriteGalleryHtml($html_name, $gallery_vars);
	}
}

exit($n_errors == 0 ? 0 : 1);

# Usage()
#
# Prints a usage message with optional error message and exit with error status.
# Never returns
sub Usage
{
	my ($msg) = @_;

	if ( defined $msg )
	{
		print STDERR "$msg\n";
	}
	print STDERR "Usage: make-gallery.pl input.gallery output-dir\n";
	exit(1);
}

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

# ReadGalleryFile()
#
# Reads the gallery file into variables, reporting errors on the way.
# Returns the number of errors found.
sub ReadGalleryFile
{
	my ($filename) = @_;
	my $n_errors = 0;
	my $file;
	my $lineno = 1;

	open($file, "<$filename") or die "Cannot open $filename for reading.\n";

	while ( <$file> )
	{
		chomp;
		my $line = Trim($_);

		print STDOUT "\"$line\"\n" if ($DBG >= 999);

		if ( ( $line eq "" ) || ( $line =~ m{^\#} ) )
		{
			# Ignore blanks lines and comments
			print STDOUT "Blank\n" if ($DBG >= 999);
		}
		else
		{
			print STDOUT "Not blank\n" if ($DBG >= 999);

			my ($kw, $val) = $line =~ m{^([^:]*):(.*)$};
			if ( defined $kw )
			{
				my $keyword = Trim($kw);
				my $value = Trim($val);

				print STDOUT "Keyword = \"$keyword\" Value = \"$value\"\n" if ($DBG >= 10);

				if ( $keyword eq "" )
				{
					print STDERR "Blank keyword found in line $lineno.\n";
					$n_errors++;
				}
				elsif ( $value eq "" )
				{
					print STDERR "Blank value found in line $lineno.\n";
					$n_errors++;
				}
				elsif ( lc($keyword) eq "title" )
				{
					if ( defined $gallery_title )
					{
						print STDERR "Redefined Title found  in line $lineno.\n";
						$n_errors++;
					}
					else
					{
						$gallery_title = $value;
					}
				}
				elsif ( lc($keyword) eq "header" )
				{
					if ( defined $gallery_header )
					{
						print STDERR "Redefined Header found  in line $lineno.\n";
						$n_errors++;
					}
					else
					{
						$gallery_header = $value;
					}
				}
				elsif ( lc($keyword) eq "text" )
				{
					if ( defined $gallery_text )
					{
						$gallery_text = $gallery_text . $text_line_separator . $value;
					}
					else
					{
						$gallery_text = $value;
					}
				}
				elsif ( lc($keyword) eq "filename" )
				{
					if ( defined $gallery_filename )
					{
						print STDERR "Redefined Filename found  in line $lineno.\n";
						$n_errors++;
					}
					else
					{
						$gallery_filename = $value;
					}
				}
				elsif ( lc($keyword) eq "image" )
				{
					$n_images++;
					$images[$n_images] = $value;
				}
				elsif ( lc($keyword) eq "thumb" )
				{
					if ( defined $thumbs[$n_images] )
					{
						print STDERR "Redefined Thumb for image $n_images found  in line $lineno.\n";
						$n_errors++;
					}
					else
					{
						$thumbs[$n_images] = $value;
					}
				}
				elsif ( lc($keyword) eq "caption" )
				{
					if ( defined $captions[$n_images] )
					{
						$captions[$n_images] = $captions[$n_images] . $caption_line_separator . $value;
					}
					else
					{
						$captions[$n_images] = $value;
					}
				}
				elsif ( lc($keyword) eq "subtext" )
				{
					if ( defined $subtexts[$n_images] )
					{
						$subtexts[$n_images] = $subtexts[$n_images] . $subtext_line_separator . $value;
					}
					else
					{
						$subtexts[$n_images] = $value;
					}
				}
				else
				{
					print STDERR "Unknown keyword \"$keyword\" found in line $lineno; ignored.\n";
				}
			}
			else
			{
				print STDERR "Line $lineno does not contain a keyword:value pair.\n";
				$n_errors++;
			}
		}

		$lineno++;
	}

	return $n_errors;
}

# TEMPORARY - hard-coded gallery for testing template
sub ReadGalleryFileTemp
{
	$gallery_title = "Broken boats";
	$gallery_header = "A collection of broken boats";

	$images[15] = "2014/2014-06/2014-06-08-0243-ItStillFloats.jpeg";
	$thumbs[15] = "2014/2014-06/thumbs/2014-06-08-0243-ItStillFloats-thumb.jpeg";

	$images[16] = "2014/2014-06/2014-06-09-0245-TwoHoles.jpeg";
	$thumbs[16] = "2014/2014-06/thumbs/2014-06-09-0245-TwoHoles-thumb.jpeg";


	$images[1] = "2013/2013-05/2013-05-25-0913-broken-boat-baiter-1a.jpeg";
	$images[2] = "2013/2013-05/2013-05-25-0914-broken-boat-baiter-1b.jpeg";
	$images[3] = "2013/2013-05/2013-05-26-0930-broken-boat-harbour.jpeg";
	$images[4] = "2013/2013-05/2013-05-28-0965-broken-boat-baiter-2a.jpeg";
	$images[5] = "2013/2013-05/2013-05-31-1022-broken-boat-fishdock-1.jpeg";
	$images[6] = "2013/2013-05/2013-05-31-1023-broken-boat-fishdock-2.jpeg";
	$images[7] = "2013/2013-05/2013-05-31-1060-broken-boat-holes-1a.jpeg";
	$images[8] = "2013/2013-05/2013-05-31-1061-broken-boat-holes-1b.jpeg";
	$images[9] = "2013/2013-05/2013-05-31-1063-broken-boat-holes-2a.jpeg";
	$images[10] = "2013/2013-05/2013-05-31-1064-broken-boat-holes-2b.jpeg";
	$images[11] = "2013/2013-05/2013-05-31-1066-broken-boat-holes-2c.jpeg";
	$images[12] = "2013/2013-05/2013-05-31-1071-broken-boat-holes-3a.jpeg";
	$images[13] = "2013/2013-05/2013-05-31-1074-broken-boat-holes-3b.jpeg";
	$images[14] = "2013/2013-05/2013-05-31-1101-prow-by-flash.jpeg";


	$thumbs[1] = "2013/2013-05/thumbs/2013-05-25-0913-broken-boat-baiter-1a-thumb.jpeg";
	$thumbs[2] = "2013/2013-05/thumbs/2013-05-25-0914-broken-boat-baiter-1b-thumb.jpeg";
	$thumbs[3] = "2013/2013-05/thumbs/2013-05-26-0930-broken-boat-harbour-thumb.jpeg";
	$thumbs[4] = "2013/2013-05/thumbs/2013-05-28-0965-broken-boat-baiter-2a-thumb.jpeg";
	$thumbs[5] = "2013/2013-05/thumbs/2013-05-31-1022-broken-boat-fishdock-1-thumb.jpeg";
	$thumbs[6] = "2013/2013-05/thumbs/2013-05-31-1023-broken-boat-fishdock-2-thumb.jpeg";
	$thumbs[7] = "2013/2013-05/thumbs/2013-05-31-1060-broken-boat-holes-1a-thumb.jpeg";
	$thumbs[8] = "2013/2013-05/thumbs/2013-05-31-1061-broken-boat-holes-1b-thumb.jpeg";
	$thumbs[9] = "2013/2013-05/thumbs/2013-05-31-1063-broken-boat-holes-2a-thumb.jpeg";
	$thumbs[10] = "2013/2013-05/thumbs/2013-05-31-1064-broken-boat-holes-2b-thumb.jpeg";
	$thumbs[11] = "2013/2013-05/thumbs/2013-05-31-1066-broken-boat-holes-2c-thumb.jpeg";
	$thumbs[12] = "2013/2013-05/thumbs/2013-05-31-1071-broken-boat-holes-3a-thumb.jpeg";
	$thumbs[13] = "2013/2013-05/thumbs/2013-05-31-1074-broken-boat-holes-3b-thumb.jpeg";
	$thumbs[14] = "2013/2013-05/thumbs/2013-05-31-1101-prow-by-flash-thumb.jpeg";

	$n_images = 16;

	return 0;
}

# ConstructGalleryVars
#
# Fills in the gaps in the gallery variables. Thumbnail names are automatically generated.
sub ConstructGalleryVars
{
	my $inum;
	my $n_errors = 0;
	my $html_name;

	if ( defined $gallery_filename )
	{
		$html_name = $out_name."/".$gallery_filename;

		if ( -e $html_name )
		{
			if ( -w $html_name )
			{
			}
			else
			{
				print STDERR "Web page \"$html_name\" is not writeable.\n";
				$n_errors++;
			}
		}
		elsif ( -w $out_name )
		{
		}
		else
		{
			print STDERR "Web page \"$html_name\" is not writeable.\n";
			$n_errors++;
		}
	}
	else
	{
		$html_name = "foo";
		print STDERR "Gallery file does not specify a file name for the web page.\n";
		$n_errors++;
	}

	for ( $inum = 1; $inum <= $n_images; $inum++ )
	{
		if ( defined $thumbs[$inum] )
		{
			# Thumb has been specified
		}
		else
		{
			# Construct a thunb filename from the image filename.
			my $f = $images[$inum];

			if ( $f =~ m{\/} )
			{
				$f =~ s/^(.*)\/([^\/]*)\.([^\.]*)$/$1\/thumbs\/$2-thumb.$3/;
			}
			else
			{
				$f =~ s/^(.*)\.([^\.]*)$/thumbs\/$1-thumb.$2/;
			}

			print STDOUT "Constructed thumb: \"$f\"\n" if ( $DBG >= 5 );
		

			$thumbs[$inum] = $f;
		}

		# TODO: Warning if image doesn't exist.
		# TODO: Warning if thumb doesn't exist.
	}

	my $gallery_vars =
	{
		gallery_title		=> $gallery_title,
		gallery_header		=> $gallery_header,
		gallery_text		=> $gallery_text,
		n_images			=> $n_images,
		images				=> \@images,
		thumbs				=> \@thumbs,
		captions			=> \@captions,
		subtexts			=> \@subtexts
	};

	return ($n_errors, $html_name, $gallery_vars);
}

# WriteGalleryHtml()
#
# Writes the HTML for the gallery to the specified filename.
# Uses the template generator.
sub WriteGalleryHtml
{
	my ($html_name, $gallery_vars) = @_;

	if ( $tt->process("gallery-index-html.tmpl", $gallery_vars, $html_name) )
	{
	}
	else
	{
		print STDERR "Template generation failed: " . $tt->error() . "\n";
	}

}
