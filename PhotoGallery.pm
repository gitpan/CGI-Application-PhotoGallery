package CGI::Application::PhotoGallery;

$VERSION = '0.02';

use strict;
use base 'CGI::Application';
use File::Basename;

my %headers = (
	png  => 'image/png',
	gif  => 'image/gif',
	jpg  => 'image/jpeg',
	jpeg => 'image/jpeg'
);

my %sizes   = (
	l    => 150,
	m    => 100,
	s    => 50
);

sub setup {
	my $self = shift;

	$self->mode_param( 'mode' );
	$self->run_modes(
		index    => 'gallery_index',
		thumb    => 'thumbnail',
		full     => 'show_image',
		view     => 'single_index',
		AUTOLOAD => 'gallery_index'
	);
	$self->start_mode( 'index' );

	# setup defaults

	$self->param( 'thumb_size'     => 'm' ) unless defined $self->param( 'thumb_size' );
	$self->param( 'thumbs_per_row' => 4 ) unless defined $self->param( 'thumbs_per_row' );
	$self->param( 'title'          => 'My Photo Gallery' ) unless defined $self->param( 'title' );
	$self->param( 'graphics_lib'   => 'GD' ) unless defined $self->param( 'graphics_lib' );
	$self->param( 'extensions'     => [ keys( %headers ) ] ) unless defined $self->param( 'extensions' );

	# check required params

	die "PARAMS => { photos_dir   => '/path/to/photos' } not set in your instance script!" unless defined $self->param( 'photos_dir' );
	die 'PARAMS => { script_name  => $0 } not set in your instance script!' unless defined $self->param( 'script_name' );

	# fixes $0 for win32

	$self->param( 'script_name' => basename( $self->param( 'script_name' ) ) );
}

sub gallery_index {
	my $self       = shift;

	my %extensions = map { $_ => 1 } @{ $self->param( 'extensions' ) };
	my $row_limit  = $self->param( 'thumbs_per_row');
	my $image_dir  = $self->param('photos_dir');

	# read the contents of the directory

	my @dir_row;
	while(my $dir = <$image_dir/*>) {
		next unless -d $dir;

		my $dir_row       = { dir => substr( $dir, length( $image_dir ) + 1 ) };
		my ( $row, $col ) = ( 0, 0 );

		while ( my $full = <$dir/*> ) {
			my ( $file, $ext ) = ( fileparse( $full, keys %extensions ) )[ 0, 2 ];

			next unless $extensions{ lc( $ext ) };
			next if $file =~ /_thumb\.$/;

			push @{ $dir_row->{ file_row }[ $col ]{ images } }, {
				filename => substr( $full, length( $image_dir ) ),
				alt      => substr( $file, 0, length( $file ) - 1 )
			};

			$col++ unless ++$row % $row_limit;
		}
		while ( $row++ % $row_limit ) {
			push @{ $dir_row->{ file_row }[ $col ]{ images } }, { filename => '', alt => '' };
		}

		push @dir_row, $dir_row;
	}

	# setup index template

	my $html = $self->load_tmpl(
		$self->param( 'index_template' ) || ( 'CGI/Application/PhotoGallery/photos_index.tmpl', path => [@INC] ),
		global_vars       => 1,
		loop_context_vars => 1
	);

	$html->param(
		script_name => $self->param( 'script_name' ),
		title       => $self->param( 'title' ),
		dir_row     => \@dir_row
	);

	return $html->output;
}

sub thumbnail {
	my $self  = shift;
	my $query = $self->query();
	my $dir   = $self->param( 'photos_dir' );
	my $image = $query->param( 'image' );
	my $size  = $self->param( 'thumb_size' );

	die 'ERROR: Missing image query argument.' unless $image;

	my( $path, $type ) = $image =~ /(.*)\.([^.]+)/;

	my $thumb  = "$dir$path" . '_thumb.png';

	my $exists = ( -e $thumb ) ? 1 : 0;

	my $data;

	# image not cached, or a newer version needs to be cached

	if ( !$exists or ( $exists and ( stat( $thumb ) )[ 9 ] < ( stat( "$dir$image" ) )[ 9 ] ) ) {
		# load graphics library
		my $graphics_lib = $self->param( 'graphics_lib' );
		require "CGI/Application/PhotoGallery/$graphics_lib.pm";
		my $gfx_lib = "CGI::Application::PhotoGallery::$graphics_lib"->new;

		$data = $gfx_lib->resize( "$dir$image", $sizes{ $size } );

		open( THUMB, ">$thumb" ) or die "ERROR: Cannot open $thumb: $!";
		binmode( THUMB );
		print THUMB $data;
		close( THUMB );
	}

	# image was cached

	else {
		open( THUMB, $thumb ) or die "ERROR: Cannot open $thumb: $!";
		binmode( THUMB );
		local $/;
		$data = <THUMB>;
		close( THUMB );
	}

	$self->header_props( { -type => 'image/png' } );
	return $data;
}

sub show_image {
	my $self  = shift;
	my $query = $self->query();
	my $dir   = $self->param( 'photos_dir' );
	my $image = $query->param( 'image' );

	die 'ERROR: Missing image query argument.' unless $image;

	# load and print image

	local $/;
	open( IMAGE, "$dir$image" ) or die "ERROR: Cannot open $dir$image: $!";
	binmode( IMAGE );
	my $data = <IMAGE>;
	close( IMAGE );

	my( $path, $type ) = $image =~ /(.*)\.([^.]+)/;

	$self->header_props( { -type => $headers{ lc( $type ) } } );
	return $data;
}

sub single_index {
	my $self  = shift;
	my $query = $self->query();
	my $dir   = $self->param( 'photos_dir' );
	my $image = $query->param( 'image' );

	die 'ERROR: Missing image query argument.' unless $image;

	my( $path, $type ) = $image =~ /(.*)\.([^.]+)/;

	# load graphics library

	my $graphics_lib = $self->param( 'graphics_lib' );
	require "CGI/Application/PhotoGallery/$graphics_lib.pm";
	my $gfx_lib = "CGI::Application::PhotoGallery::$graphics_lib"->new;

	my ( $width, $height ) = $gfx_lib->size( "$dir$image" );

	# setup single photo template

	my $html = $self->load_tmpl(
		$self->param( 'single_template' ) || ( 'CGI/Application/PhotoGallery/photos_single.tmpl', path => [@INC] ),
		global_vars => 1,
	);

	$html->param(
		script_name => $self->param( 'script_name' ),
		title       => $self->param( 'title' ) . ' - ' . $path,
		filename    => $query->param( 'image' ),
		alt         => $query->param( 'image' ),
		width       => $width,
		height      => $height
	);

	# get caption, if available

	if ( -e "$dir$path.txt" ) {
		local $/;
		open( CAPTION, "$dir$path.txt" ) or die "ERROR: Cannot open $dir$path.txt: $!";
		$html->param( caption => <CAPTION> );
		close CAPTION;
	}

	return $html->output;
}

1;

__END__

=head1 NAME

CGI::Application::PhotoGallery - module to provide a simple photo gallery.

=head1 SYNOPSIS

	use CGI::Application::PhotoGallery;
	my $webapp = CGI::Application::PhotoGallery->new(
		PARAMS => {
			photos_dir => '/path/to/photos',
			script_name => $0
		}
        );
	$webapp->run();

=head1 DESCRIPTION

CGI::Application::PhotoGallery is a CGI::Application module allowing people
to create their own simple photo gallery. There is no need to generate your
own thumbnails since they are created on the fly (using either the GD or
Image::Magick modules).

To use this module you need to create an instance script.  It
should look like:

	#!/usr/bin/perl
	use CGI::Application::PhotoGallery;
	my $webapp = CGI::Application::PhotoGallery->new(
		PARAMS => {
			photos_dir => '/path/to/photos',
			script_name => $0
		}
	);
	$webapp->run();

You'll need to replace the "/path/to/photos" with the real path to your
photos. There is no need to change the "script_name" parameter.

Put this somewhere where CGIs can run and name it something like
C<index.cgi>.

This gets you the default behavior and look.  To get something more to
your specifications you can use the options described below.

=head1 OPTIONS

CGI::Application modules accept options using the PARAMS arguement to
C<new()>.  To give options for this module you change the C<new()>
call in the instance script shown above:

	my $webapp = CGI::Application::PhotoGallery->new(
		PARAMS => {
			photos_dir => '/path/to/photos',
			script_name => $0,
			title => 'My Photos'
		}
	);

The C<title> option tells PhotoGallery to use 'My Photos' as the title
rather than the default value.  See below for more information
about C<title> and other options.

=over 4

=item * photos_dir (required)

This parameter is used to specify where all of your photos are
located. PhotoGallery needs to know this so i can display all of
your photos.

=item * script_name (required)

This parameter should stay as C<$0>. It is needed because PhotoGallery
links to itself and needs to know the name of the instance script.

=item * title

By default every page will start with the title "My Photo Gallery".
You can specify your own using the title parameter.

=item * thumb_size

By default PhotoGallery displays thumbnail images that are 100 x 100
on the index page. You can change this by specifying either C<'s'>
(50 x 50), C<'m'> (100 x 100) or C<'l'> (150 x 150) for this option.

=item * thumbs_per_row

The default number of thumbnails per row on the index page is C<4>. You
can change it by specifying your own value in the instance script.

=item * graphics_lib

You can specifify which graphics library you wish to use to size your
thumbnails. Included in this package are C<Magick> (Image::Magick) and
the default: C<GD>. You can also create your own if you wish.

=item * extensions

Should you wish, you can also specify the allowable extensions. The
defaults are: C<png>, C<gif>, C<jpg> and C<jpeg>.

=item * index_template

This application uses HTML::Template to generate its HTML pages.  If
you would like to customize the HTML you can copy the default form
template and edit it to suite your needs.  The default form template
is called 'photos_index.tmpl' and you can get it from the distribution
or from wherever this module ended up in your C<@INC>.  Pass in the
path to your custom template as the value of this parameter.

See L<HTML::Template|HTML::Template> for more information about the
template syntax.

=item * single_template

The default template for an individual photo is called
'photos_single.tmpl' and you can get it from the distribution or from
wherever this module ended up in your C<@INC>.  Pass in the path to
your custom template as the value of this parameter.

See L<HTML::Template> for more information about the template syntax.

=head1 AUTHOR

Copyright 2002 - 2003, Brian Cassidy (brian@alternation.net).

Special thanks to jeffa, vladb, petruchio and jcwren from
http://www.perlmonks.org for their help.

Thanks also to:
Mark Stosberg
Michael Heathman

Questions, bug reports and suggestions can be emailed directly to me
at brian@alternation.net. I would also suggest subscribing to the
CGI::Application mailinglist by sending a blank message to
"cgiapp-subscribe@lists.erlbaum.net".

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<CGI::Application|CGI::Application>, L<HTML::Template|HTML::Template>, L<CGI::Application::MailPage|CGI::Application::MailPage>

=cut