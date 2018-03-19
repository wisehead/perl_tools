use ExtUtils::MakeMaker;
$Verbose = 1;
WriteMakefile(
    NAME   => 'similar_text::similarity',
    SKIP   => [qw(all static static_lib dynamic dynamic_lib)],
    clean  => {'FILES' => 'libsimilarity$(LIB_EXT)'},
);
sub MY::top_targets {
'
all :: static
pure_all :: static
static ::       libsimilarity$(LIB_EXT)
libsimilarity$(LIB_EXT): $(O_FILES)
		$(AR) cr libsimilarity$(LIB_EXT) $(O_FILES)
		$(RANLIB) libsimilarity$(LIB_EXT)
';
}
