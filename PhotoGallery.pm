package CGI::Application::PhotoGallery;

use strict;
use CGI::Application;
use File::Basename;
use GD;

use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(CGI::Application);

sub setup {
	my $self = shift;
	$self->mode_param('r');
	$self->run_modes(
		'0' => 'show_gallery',
		'1' => 'show_image',
		'AUTOLOAD' => 'show_gallery'
	);
	$self->start_mode('0');

	# setup defaults
	$self->param('thumb_size' => 'm') unless defined $self->param('thumb_size');
	$self->param('thumbs_per_row' => 4) unless defined $self->param('thumbs_per_row');
	$self->param('title' => 'My Photo Gallery') unless defined $self->param('title');

	# check required params
	die "You must set PARAMS => { photos_dir => '/path/to/photos' } in your PhotoGallery instance script!" unless defined $self->param('photos_dir');
	die "You must set PARAMS => { script_name => \$0 } in your PhotoGallery instance script!" unless defined $self->param('script_name');
}

sub show_gallery {
	my $self = shift;

	my $row_limit = $self->param('thumbs_per_row');
	my %ok_ext = map { $_ => 1 } qw(jpg gif png);
	my $image_dir = $self->param('photos_dir');

	# read the contents of the directory
	my @dir_row;
	while(my $dir = <$image_dir/*>) {
		next unless -d $dir;
		my $dir_row = {dir => substr($dir, length($image_dir) + 1)};

		my ($i, $j) = (0, 0);
		while (my $full = <$dir/*>) {
			my ($file, $ext) = (fileparse($full,keys %ok_ext))[0,2];
			next unless $ok_ext{$ext};

			push @{$dir_row->{file_row}->[$j]->{images}}, { filename => substr($full, length($self->param('photos_dir'))), alt => $file };
			$j++ unless ++$i % $row_limit;
		}
		for ($i = $i; $i % $row_limit; $i++) {
			push @{$dir_row->{file_row}->[$j]->{images}}, { filename => '', alt => '' };
		}

		push @dir_row, $dir_row;
	}

	# setup index template
	my $html;
	if ($self->param('index_template')) {
		$html = $self->load_tmpl(
			$self->param('index_template'),
			global_vars => 1
		);
	}
	else {
		$html = $self->load_tmpl(
			'CGI/Application/PhotoGallery/photos_index.tmpl',
			path => [@INC],
			global_vars => 1
		);
	}

	$html->param(
		script_name => $self->param('script_name'),
		thumb_size => $self->param('thumb_size'),
		title => $self->param('title'),
		dir_row => \@dir_row
	);
	return $html->output;
}

sub show_image {
	my $self = shift;
	my $q = $self->query();

	# load image
	die "Missing image query argument." unless defined($q->param('i'));
	my $image = GD::Image->new($self->param('photos_dir') . $q->param('i'));

	# resize image, if needed
	my $newimage;
	if (defined($q->param('l'))) {
		$newimage = $self->resize_image(150, $image);
	}
	elsif (defined($q->param('m'))) {
		$newimage = $self->resize_image(100, $image);
	}
	elsif (defined($q->param('s'))) {
		$newimage = $self->resize_image(50, $image);
	}
	elsif (defined($q->param('f'))) {
		my $type = substr($q->param('i'), length($q->param('i')) - 3);
		if ($type eq 'jpg') {
			$self->header_props({-type=>'image/jpeg'});
			return $image->jpeg;
		}
		elsif ($type eq 'png' || $type eq 'gif') {
			$self->header_props({-type=>'image/png'});
			return $image->png;
		}
	}
	else {
		my ($width, $height) = $image->getBounds();

		# setup single photo template
		my $html;
		if ($self->param('single_template')) {
			$html = $self->load_tmpl(
				$self->param('single_template'),
				global_vars => 1
			);
		}
		else {
			$html = $self->load_tmpl(
				'CGI/Application/PhotoGallery/photos_single.tmpl',
				path => [@INC],
				global_vars => 1
			);
		}

		$html->param(
			script_name => $self->param('script_name'),
			title => $self->param('title') . ' - ' . substr($q->param('i'), 0, length($q->param('i')) - 4),
			filename => $q->param('i'),
			alt => $q->param('i'),
			width => $width,
			height => $height
		);

		# get caption, if available
		my $file = $self->param('photos_dir') . substr($q->param('i'), 0, length($q->param('i')) - 4);
		open (FH, "<$file.txt");
		local $/ = undef;
		$html->param(caption => <FH>);
		close FH;
		return $html->output;
	}
	$self->header_props({-type=>'image/png'});
	return $newimage->png;
}

sub resize_image {
	my ($self, $newsize, $image) = @_;
	my ($width, $height) = $image->getBounds();
	my $image2 = new GD::Image($newsize, $newsize);

	$image2->transparent($image2->colorAllocate(0,0,0));

	if ($width > $height) {
		$image2->copyResized($image, 0, int((($newsize - int(($height * $newsize / $width) + 0.5)) / 2) + 0.5), 0, 0, $newsize, int(($height * $newsize / $width) + 0.5), $width, $height);
	}
	elsif ($width < $height) {
		$image2->copyResized($image, int((($newsize - int(($width * $newsize / $height) + 0.5)) / 2) + 0.5), 0, 0, 0, int(($width * $newsize / $height) + 0.5), $newsize, $width, $height);
	}
	else {
		$image2->copyResized($image, 0, 0, 0, 0, $newsize, $newsize, $width, $height);
	}

	return $image2;
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
own thumbnails since they are created on the fly (using the GD module).

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

The default number of thumbnails per row on the index page is 4. You
can change it by specifying your own value in the instance script.

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

Copyright 2002, Brian Cassidy (brian@alternation.net).

Special thanks to jeffa, vladb, petruchio and jcwren from
http://www.perlmonks.org for their help.

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