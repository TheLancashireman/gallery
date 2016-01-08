#!/usr/bin/perl -wT
#
# gen-album.pl - generate a photo album
#
# (c) 2016 David Haworth
#
# This file is part of dhGalleryMaker.
#
# dhGalleryMaker is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# dhGalleryMaker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with dhGalleryMaker.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id$

# ========================================
#
# gen-album.pl is intended to run as a CGI "GET" script,
# but can be made to run locally by means of a wrapper script
# that sets up the expected CGI environment variables.
#
# To use this script:
#
# 1. Create a master directory on your webserver to hold your albums.
# 2. Place this script in the master directory and make it executable.
# 3. Configure your web server to execute the script.
# 4. Place all your "album" files into the master directory. They can be in a subdirectory (see $album_dir).
# 5. Place all your photos into the master directory. It is probably best to use subdirectories.
# 6. Configure the variables in the "Configuration" section below.
#
# The photo subdirectories can be directly in the master directory, or you can create a "photos" subsirectory
# and place them there.
#
# Configuration:
#  $album_dir
#    is the place where the albums can be found. This is used by the script when it reads an album
#    file, so it must be relative to the DOCUMENT_ROOT environment variable.
#
#  $photo_dir
#    is the place where the photos can be found, relative to the master directory. So if you have
#    created a "photos" subdirectory in step 5, this should be the name of that directory.
#
#  $text_line_separator
#  $caption_line_separator
#  $subtext_line_separator
#    these are used when reading the album files. They are used for joining together multiple
#    lines of album text (keyword "Text"), photo caption (keyword "Caption") and photo subtext (keyword
#    "Subtext"), respectively.  #    A newline is usually OK, but you might like to experiment with <br/>\n

# ========================================
#
# === Configuration section ==============
#
my $album_dir = "photo-album/albums";	# Relative to DOCUMENT_ROOT.
my $photo_dir = "";						# Relative to the script's directory.
#my $photo_dir = "photos";				# Relative to the script's directory.

my $text_line_separator = "\n";
my $caption_line_separator = "\n";
my $subtext_line_separator = "\n";

# === End of configuration section =======
#
# ========================================

# Data read from album file or constructed using default values
my $album_title;
my $album_heading;
my $album_text;
my $image_dir;
my $n_images = 0;
my @images;
my @thumbs;
my @captions;
my @subtexts;

# Assorted variables
my $DBG = 0;
my $n_errors;
my $errmsg;
my $image_index;
my $mobile = 0;

# Make sure the document root is defined and is a directory. Error page if not!
my $docroot = $ENV{"DOCUMENT_ROOT"};
if ( !defined $docroot )
{
	error_page(2001, "Server error - DOCUMENT_ROOT is not defined.");
}

if ( ! -d $docroot )
{
	error_page(2002, "Server error - DOCUMENT_ROOT does not specify a directory.");
}

# Make sure that the request method is GET. Error page if not!
my $rm = $ENV{"REQUEST_METHOD"};
if ( !defined $rm || $rm ne "GET" )
{
	error_page(1001, "An unexpected REQUEST_METHOD ($rm) was used with this script.");
}

# Make sure the script name is defined. Error page if not!
my $script_name = $ENV{"SCRIPT_NAME"};
if ( !defined $script_name )
{
	error_page(2003, "Server error - SCRIPT_NAME is not defined.");
}

# Get the query stringi (i.e. what comes after the ? in the URI).
#	- The first parameter is the album name.
#	- The remaining parameters are options of the form foo=bar
my $qs = $ENV{"QUERY_STRING"};
my @qparams = split(/&/, $qs);
my $album_name = $qparams[0];

# Make sure the album name is defined. Error page if not!
if ( !defined $album_name )
{
	error_page(1002, "This script was invoked without an album name.");
}

my $i = 1;
while ( defined $qparams[$i] )
{
	process_opt($qparams[$i]);
	$i++;
}

# Set up the mobile=1 option if the mobile site is in use.
my $mob = "";
$mob = "&mobile=1" if ( $mobile );

my $album_filename = $docroot . "/" . $album_dir . "/" . $album_name . ".album";

if ( ! -r $album_filename )
{
	error_page(1003, "The specified album ($album_name) doesn't exist.");
}

($n_errors, $errmsg) = read_album($album_filename);

if ( $n_errors != 0 )
{
	error_page(1004, "Error parsing $album_filename", $errmsg);
}

# Fill in the blanks...
$album_title = "Untitled album" if ( !defined $album_title );
$album_heading = "Untitled album" if ( !defined $album_heading );
$album_text = "" if ( !defined $album_text );

# Prepend directories, create default thumbnail files.
fixup_images();

# Create the HTML body
my $body;
my $stylesheet;

if ( defined $image_index )
{
	if ( $image_index >= 0 && $image_index < $n_images )
	{
		$body = create_navigator_html($image_index);
		$stylesheet = "photo-navigator";
	}
	else
	{
		error_page(1006, "Image index out of range", "There is no image $image_index in this album.");
	}
}
else
{
	# No image was specified. 
	$body = create_album_html($album_heading, $album_text);
	$stylesheet = "photo-album";
}

# Spew out the page
print_page($album_title, $body, $stylesheet);

# That's it!
exit 0;


# ==================================================
#
# Functions used ...

# process_opt() - processes a single option of the form 'keyword=value'
sub process_opt
{
	my ($opt) = @_;

	# Options are of the form keyword=value. Anything unknown is ignored
	my ($kw, $val) = $opt =~ m{^(.+)=(.+)$};
	my $nval;

	if ( $val eq "0" )
	{
		$nval = 0;
	}
	else
	{
		($nval) = $val =~ m{^([1-9][0-9]*)$};
	}

	if ( defined $kw && defined $val )
	{
		$kw = lc($kw);

		if ( $kw eq "image" )
		{
			if ( !defined $nval )
			{
				error_page(1005, "Non-numeric value specified for the image identifier",
							"Parameter was \"$opt\"");
			}
			$image_index = $nval;
		}
		elsif ( $kw eq "mobile" )
		{
			$mobile = 1 if ( defined $nval && $nval == 1 );
		}
	}
}

# print_page() - prints the page; content type, doctype and the html head and body
sub print_page
{
	my ($title, $body_html, $css) = @_;

	print <<EOF;
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="description" content="" />
  <meta name="author" content="TheLancashireman" />
  <meta name="generator" content="dhGalleryMaker" />

  <title>$title</title>

  <link rel="stylesheet" type="text/css" href="/styles/$css.css"/>
 </head>

 <body>
$body_html
 </body>
</html>
EOF
}

# error-page() - prints an error page
sub error_page
{
	my ($errcode, $errmsg, $errinfo) = @_;
	my $body;

	$errinfo = "" if ( !defined $errinfo );

	$body  = <<EOF;
  <div id="album">
   <h1>Sorry, an error has occurred</h1>
   <p>$errmsg</p>
   <p>Error number $errcode</p>
   <p>$errinfo</p>
  </div>
EOF

	print_page("Error", $body, "photo-album");
	exit(1);
}

# read_album() - reads an album (a textual description) and stores it
sub read_album
{
	my ($filename) = @_;
	my $n_errors = 0;
	my $file;
	my $lineno = 1;
	my $errstr = "<h3>The following errors were found while parsing $filename:</h3>\n";
	my $this_image = -1;

	# Open the album file. The file should have been checked for existence already.
	open($file, "<$filename") or error_page(2002, "Cannot open $filename for reading.");

	# Read and process every line of the album file.
	while ( <$file> )
	{
		chomp;
		my $line = trim($_);

		if ( ( $line eq "" ) || ( $line =~ m{^\#} ) )
		{
			# Ignore blanks lines and comments
		}
		else
		{
			# Lines are of the form "Keyword: text"
			my ($kw, $val) = $line =~ m{^([^:]*):(.*)$};
			if ( defined $kw )
			{
				my $keyword = trim($kw);
				my $value = trim($val);

				if ( $keyword eq "" )
				{
					$errstr = adderr($errstr, "Blank keyword found in line $lineno.");
					$n_errors++;
				}
				elsif ( $value eq "" )
				{
					$errstr = adderr($errstr, "Blank value found in line $lineno.");
					$n_errors++;
				}
				elsif ( lc($keyword) eq "title" )
				{
					if ( defined $album_title )
					{
						$errstr = adderr($errstr, "Redefined Title found  in line $lineno.");
						$n_errors++;
					}
					else
					{
						$album_title = $value;
					}
				}
				elsif ( lc($keyword) eq "header" )
				{
					if ( defined $album_heading )
					{
						$errstr = adderr($errstr, "Redefined Header found  in line $lineno.");
						$n_errors++;
					}
					else
					{
						$album_heading = $value;
					}
				}
				elsif ( lc($keyword) eq "text" )
				{
					if ( defined $album_text )
					{
						$album_text = $album_text . $text_line_separator . $value;
					}
					else
					{
						$album_text = $value;
					}
				}
				elsif ( lc($keyword) eq "filename" )
				{
					# This information is no longer used.
				}
				elsif ( lc($keyword) eq "imagedir" )
				{
					if ( defined $image_dir )
					{
						$errstr = adderr($errstr, "Redefined ImageDir found  in line $lineno.");
						$n_errors++;
					}
					else
					{
						$image_dir = $value;
					}
				}
				elsif ( lc($keyword) eq "image" )
				{
					$this_image = $n_images;
					$n_images++;
					$images[$this_image] = $value;
				}
				elsif ( lc($keyword) eq "thumb" )
				{
					if ( $this_image < 0 )
					{
						$errstr = adderr($errstr, "Thumb found but no previous Image in line $lineno.");
					}
					elsif ( defined $thumbs[$this_image] )
					{
						$errstr = adderr($errstr, "Redefined Thumb for image $n_images found  in line $lineno.");
						$n_errors++;
					}
					else
					{
						$thumbs[$this_image] = $value;
					}
				}
				elsif ( lc($keyword) eq "caption" )
				{
					if ( $this_image < 0 )
					{
						$errstr = adderr($errstr, "Caption found but no previous Image in line $lineno.");
					}
					elsif ( defined $captions[$this_image] )
					{
						$captions[$this_image] = $captions[$this_image] . $caption_line_separator . $value;
					}
					else
					{
						$captions[$this_image] = $value;
					}
				}
				elsif ( lc($keyword) eq "subtext" )
				{
					if ( $this_image < 0 )
					{
						$errstr = adderr($errstr, "Subtext found but no previous Image in line $lineno.");
					}
					elsif ( defined $subtexts[$this_image] )
					{
						$subtexts[$this_image] = $subtexts[$this_image] . $subtext_line_separator . $value;
					}
					else
					{
						$subtexts[$this_image] = $value;
					}
				}
				else
				{
					$errstr = adderr($errstr, "Unknown keyword \"$keyword\" found in line $lineno.");
					$n_errors++;
				}
			}
			else
			{
				$errstr = adderr($errstr, "Line $lineno does not contain a keyword:value pair.");
				$n_errors++;
			}
		}

		$lineno++;
	}

	close($file);

	return($n_errors, $errstr);
}

# fixup_images() - prepend the image directory to all images and thumbnails
sub fixup_images
{
	my $i;
	my $pre = "";

	$pre = $photo_dir . "/" if ( $photo_dir ne "" );

	if ( defined $image_dir && $image_dir ne "" )
	{
		$pre .= $image_dir . "/";
	}

	for ( $i = 0; $i < $n_images; $i++ )
	{
		# Prepend the image directory to the image filename.
		$images[$i] = $pre . $images[$i];

		if ( defined $thumbs[$i] )
		{
			# Thumb has been specified. Just prepend the image directory to the thumb filename.
			$thumbs[$i] = $pre . $thumbs[$i];
		}
		else
		{
			# Construct a thumb filename from the image filename (which is already fixed up).
			my $f = $images[$i];

			if ( $f =~ m{\/} )
			{
				$f =~ s/^(.*)\/([^\/]*)\.([^\.]*)$/$1\/thumbs\/$2-thumb.$3/;
			}
			else
			{
				$f =~ s/^(.*)\.([^\.]*)$/thumbs\/$1-thumb.$2/;
			}

			$thumbs[$i] = $f;
		}
	}
}

# create_album_html() - creates the HTML for the album page containing all the thumbnails
sub create_album_html
{
	my ($body_heading, $body_text) = @_;
	my ($html, $i, $im, $th);

	$html  = <<EOF;
  <div id="album">
   <h1>$body_heading</h1>
EOF
	if ( defined $body_text && $body_text ne "" )
	{
		$html .= <<EOF;
   <p>$body_text</p>

EOF
	}
	else
	{
		$html .= <<EOF;

EOF
	}

	for ( $i = 0; $i < $n_images; $i++ )
	{
		$im = $images[$i];
		$th = $thumbs[$i];

		$html .= <<EOF;
   <a href="$script_name?$album_name&image=$i$mob"><img
      src="$th"
      alt="$im"></a>

EOF
	}

		$html .= <<EOF;

  </div>
EOF

	return $html;
}

# create_navigator_html() - creates the HTML for a navigator page containing one image
sub create_navigator_html
{
	my ($image_index) = @_;
	my ($html);
	my ($title, $subtitle, $image);		# For the images on this page.
	my ($prev_index, $prev_html);
	my ($next_index, $next_html);
	my ($this_html, $albhead_html, $back_html);

	# Pull info from arrays and fill in the blanks.
	$title = $captions[$image_index];
	$subtitle = $subtexts[$image_index];
	$image = $images[$image_index];

	$title = "" if ( !defined $title );
	$subtitle = "" if ( !defined $subtitle );

	if ( $mobile )
	{
		# No album heading for mobile site - it's too wide.
		$albhead_html = "";
	}
	else
	{
		$albhead_html = <<EOF;
    <div id="nav-albuminfo" class="nav-section">
     <h2>$album_heading<h2>
     <hr/>
    </div>
EOF
	}

	if ( $mobile )
	{
		$back_html = <<EOF;
    <div id="nav-back" class="nav-section">
     <a href="$script_name?$album_name"><h4>Index</h4></a>
     <hr/>
    </div>
EOF
	}
	else
	{
		$back_html = <<EOF;
    <div id="nav-back" class="nav-section">
     <a href="$script_name?$album_name"><h4>Back to index</h4></a>
     <hr/>
    </div>
EOF
	}

	if ( $mobile || $title eq "" )
	{
		# No image info for mobile site - it's too wide.
		$this_html = "";
	}
	else
	{
		$this_html = <<EOF;
    <div id="nav-imageinfo" class="nav-section">
     <h4>This image:</h4>
     <a href="$image"><h3>$title</h3></a>
     <p>$subtitle</p>
     <hr/>
    </div>
EOF
	}

	$prev_index = $image_index-1;
	if ( $prev_index < 0 )
	{
		# There's no "previous" image.
		$prev_html = "";
	}
	else
	{
		my $prev_image = $images[$prev_index];
		my $prev_thumb = $thumbs[$prev_index];

		$prev_html = <<EOF;
    <div id="nav-prev" class="nav-section">
     <a href="$script_name?$album_name&image=$prev_index$mob"><h4>Previous:</h4></a>
     <a href="$script_name?$album_name&image=$prev_index$mob"><img
        class="fit-panel"
        src="$prev_thumb"
        alt="$prev_image"></a>
     <hr/>
    </div>
EOF
	}

	$next_index = $image_index+1;
	if ( $next_index >= $n_images )
	{
		# There's no "next" image.
		$next_html = "";

	}
	else
	{
		my $next_image = $images[$next_index];
		my $next_thumb = $thumbs[$next_index];

		$next_html = <<EOF;
    <div id="nav-next" class="nav-section">
     <a href="$script_name?$album_name&image=$next_index$mob"><h4>Next:</h4></a>
     <a href="$script_name?$album_name&image=$next_index$mob"><img
        class="fit-panel"
        src="$next_thumb"
        alt="$next_image"></a>
     <hr/>
    </div>
EOF
	}

	$html  = <<EOF;
  <div id="navigator">
   <div id="nav-left">
$albhead_hml
$next_html
$prev_html
$back_html
$this_html
   </div>
   <div id="nav-right">
    <div id="nav-right-top"> </div>
    <a href="$image"><img
       class="fit-panel"
       src="$image"
       alt="$image"></a>
   </div>
  </div>
EOF

	return $html;
}

# trim() - trims leading and trailing spaces from  a string and returns the result.
sub trim
{
    my ($txt) = @_;
    $txt =~ s/^\s*(\S.*)$/$1/;
    $txt =~ s/^(.*\S)\s*$/$1/;
    return $txt;
}

# adderr() - add an error message to the existing error message string
sub adderr
{
    my ($errs, $newerr) = @_;
	$errs .= "<p>$newerr</p>\n";
    return $errs;
}
