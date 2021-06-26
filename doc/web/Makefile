# This Makefile requires that `pandoc` be installed:
#     https://pandoc.org


# convert each Markdown source file to an HTML file for the website
html_from_md:
	# the below listing is lexicographic, as when browsing files
	#
	# `content/`
	pandoc -f gfm -t html -o content/community.html \
		content/community.md
	pandoc -f gfm -t html -o content/documentation.html \
		content/documentation.md
	pandoc -f gfm -t html -o content/download.html \
		content/download.md
	pandoc -f gfm -t html -o content/home.html \
		content/home.md
	# `content/community/`
	pandoc -f gfm -t html -o content/community/contact.html \
		content/community/contact.md
	pandoc -f gfm -t html -o content/community/developers.html \
		content/community/developers.md
	pandoc -f gfm -t html -o content/community/tla+_net.html \
		content/community/tla+_net.md
	# `content/documentation/`
	pandoc -f gfm -t html -o content/documentation/misc.html \
		content/documentation/misc.md
	pandoc -f gfm -t html -o content/documentation/publications.html \
		content/documentation/publications.md
	pandoc -f gfm -t html -o content/documentation/tla+_hyperbook.html \
		content/documentation/tla+_hyperbook.md
	pandoc -f gfm -t html -o content/Documentation/tla+_video_course.html \
		content/documentation/tla+_video_course.md
	pandoc -f gfm -t html -o content/documentation/tutorial.html \
		content/documentation/tutorial.md
	pandoc -f gfm -t html -o content/documentation/unsupported_features.html \
		content/documentation/unsupported_features.md
	# `content/documentation/tutorial/`
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/a_simple_proof.html \
		content/documentation/tutorial/a_simple_proof.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/advanced_options.html \
		content/documentation/tutorial/advanced_options.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/hierarchical_proofs.html \
		content/documentation/tutorial/hierarchical_proofs.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/other_proof_constructs.html \
		content/documentation/tutorial/other_proof_constructs.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/practical_hints.html \
		content/documentation/tutorial/practical_hints.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/tactics.html \
		content/documentation/tutorial/tactics.md
	pandoc -f gfm -t html \
		-o content/documentation/tutorial/the_example.html \
		content/documentation/tutorial/the_example.md
	# `content/download/`
	pandoc -f gfm -t html -o content/download/binaries.html \
		content/download/binaries.md
	pandoc -f gfm -t html -o content/download/license.html \
		content/download/license.md
	pandoc -f gfm -t html -o content/download/previous_releases.html \
		content/download/previous_releases.md
	pandoc -f gfm -t html -o content/download/source.html \
		content/download/source.md
	pandoc -f gfm -t html -o content/download/unsupported.html \
		content/download/unsupported.md
	pandoc -f gfm -t html -o content/download/what_s_new.html \
		content/download/what_s_new.md
	# `content/download/binaries/`
	pandoc -f gfm -t html -o content/download/binaries/linux.html \
		content/download/binaries/linux.md
	pandoc -f gfm -t html -o content/download/binaries/macOS.html \
		content/download/binaries/macos.md
	pandoc -f gfm -t html -o content/download/binaries/windows.html \
		content/download/binaries/windows.md

clean:
	# `content/`
	-rm -f \
		content/community.html \
		content/documentation.html \
		content/download.html \
		content/home.html
	# `content/community/`
	rm -f \
		content/community/contact.html \
		content/community/developers.html \
		content/community/tla+_net.html
	# `content/documentation/`
	rm -f \
		content/documentation/misc.html \
		content/documentation/publications.html \
		content/documentation/tla+_hyperbook.html \
		content/documentation/tla+_video_course.html \
		content/documentation/tutorial.html \
		content/documentation/unsupported_features.html
	# `content/documentation/tutorial/`
	rm -f \
		content/documentation/tutorial/a_simple_proof.html \
		content/documentation/tutorial/advanced_options.html \
		content/documentation/tutorial/hierarchical_proofs.html \
		content/documentation/tutorial/other_proof_constructs.html \
		content/documentation/tutorial/practical_hints.html \
		content/documentation/tutorial/tactics.html \
		content/documentation/tutorial/the_example.html
	# `download/`
	rm -f \
		content/download/binaries.html \
		content/download/license.html \
		content/download/previous_releases.html \
		content/download/source.html \
		content/download/unsupported.html \
		content/download/what_s_new.html
	# `download/binaries/`
	rm -f \
		content/download/binaries/linux.html \
		content/download/binaries/macOS.html \
		content/download/binaries/windows.html
