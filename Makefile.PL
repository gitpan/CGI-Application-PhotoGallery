use ExtUtils::MakeMaker;
WriteMakefile(
              'NAME' => 'CGI::Application::PhotoGallery',
              'VERSION_FROM' => 'PhotoGallery.pm',
              'PREREQ_PM' => {
                              'File::Basename' => 0,
                              'GD' => 0,
                              'CGI::Application' => 0,
                              'HTML::Template' => 0
                             },
              'PM' => {
                       'PhotoGallery.pm' => '$(INST_LIBDIR)/PhotoGallery.pm',
                       'photos_single.tmpl' => '$(INST_LIBDIR)/PhotoGallery/photos_single.tmpl',
                       'photos_index.tmpl' => '$(INST_LIBDIR)/PhotoGallery/photos_index.tmpl',
                      },
               );


