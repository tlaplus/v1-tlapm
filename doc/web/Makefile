# This Makefile requires that `pandoc` be installed:
#     https://pandoc.org


# convert each Markdown source file to an HTML file for the website
html_from_md:
	# the below listing is lexicographic, as when browsing files
	#
	# `content/`
	pandoc -f gfm -t html -o content/Community.html \
		content/community.md
	pandoc -f gfm -t html -o content/Documentation.html \
		content/documentation.md
	pandoc -f gfm -t html -o content/Download.html \
		content/download.md
	pandoc -f gfm -t html -o content/Home.html \
		content/home.md
	# `content/Community/`
	pandoc -f gfm -t html -o content/Community/Contact.html \
		content/Community/contact.md
	pandoc -f gfm -t html -o content/Community/Developers.html \
		content/Community/developers.md
	pandoc -f gfm -t html -o content/Community/TLA+_net.html \
		content/Community/tla+_net.md
	# `content/Documentation/`
	pandoc -f gfm -t html -o content/Documentation/Misc.html \
		content/Documentation/misc.md
	pandoc -f gfm -t html -o content/Documentation/Publications.html \
		content/Documentation/publications.md
	pandoc -f gfm -t html -o content/Documentation/TLA+_Hyperbook.html \
		content/Documentation/tla+_hyperbook.md
	pandoc -f gfm -t html -o content/Documentation/TLA+_Video_Course.html \
		content/Documentation/tla+_video_course.md
	pandoc -f gfm -t html -o content/Documentation/Tutorial.html \
		content/Documentation/tutorial.md
	pandoc -f gfm -t html -o content/Documentation/Unsupported_features.html \
		content/Documentation/unsupported_features.md
	# `content/Documentation/Tutorial/`
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/A_simple_proof.html \
		content/Documentation/Tutorial/a_simple_proof.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/Advanced_options.html \
		content/Documentation/Tutorial/advanced_options.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/Hierarchical_proofs.html \
		content/Documentation/Tutorial/hierarchical_proofs.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/Other_proof_constructs.html \
		content/Documentation/Tutorial/other_proof_constructs.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/Practical_hints.html \
		content/Documentation/Tutorial/practical_hints.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/Tactics.html \
		content/Documentation/Tutorial/tactics.md
	pandoc -f gfm -t html \
		-o content/Documentation/Tutorial/The_example.html \
		content/Documentation/Tutorial/the_example.md
	# `content/Download/`
	pandoc -f gfm -t html -o content/Download/Binaries.html \
		content/Download/binaries.md
	pandoc -f gfm -t html -o content/Download/License.html \
		content/Download/license.md
	pandoc -f gfm -t html -o content/Download/Previous_releases.html \
		content/Download/previous_releases.md
	pandoc -f gfm -t html -o content/Download/Source.html \
		content/Download/source.md
	pandoc -f gfm -t html -o content/Download/Unsupported.html \
		content/Download/unsupported.md
	pandoc -f gfm -t html -o content/Download/What_s_new.html \
		content/Download/what_s_new.md
	# `content/Download/Binaries/`
	pandoc -f gfm -t html -o content/Download/Binaries/Linux.html \
		content/Download/Binaries/linux.md
	pandoc -f gfm -t html -o content/Download/Binaries/MacOS.html \
		content/Download/Binaries/macos.md
	pandoc -f gfm -t html -o content/Download/Binaries/Windows.html \
		content/Download/Binaries/windows.md

clean:
	# `content/`
	-rm -f \
		content/Community.html \
		content/Documentation.html \
		content/Download.html \
		content/Home.html
	# `content/Community/`
	rm -f \
		content/Community/Contact.html \
		content/Community/Developers.html \
		content/Community/TLA+_net.html
	# `content/Documentation/`
	rm -f \
		content/Documentation/Misc.html \
		content/Documentation/Publications.html \
		content/Documentation/TLA+_Hyperbook.html \
		content/Documentation/TLA+_Video_Course.html \
		content/Documentation/Tutorial.html \
		content/Documentation/Unsupported_features.html
	# `content/Documentation/Tutorial/`
	rm -f \
		content/Documentation/Tutorial/A_simple_proof.html \
		content/Documentation/Tutorial/Advanced_options.html \
		content/Documentation/Tutorial/Hierarchical_proofs.html \
		content/Documentation/Tutorial/Other_proof_constructs.html \
		content/Documentation/Tutorial/Practical_hints.html \
		content/Documentation/Tutorial/Tactics.html \
		content/Documentation/Tutorial/The_example.html
	# `Download/`
	rm -f \
		content/Download/Binaries.html \
		content/Download/License.html \
		content/Download/Previous_releases.html \
		content/Download/Source.html \
		content/Download/Unsupported.html \
		content/Download/What_s_new.html
	# `Download/Binaries/`
	rm -f \
		content/Download/Binaries/Linux.html \
		content/Download/Binaries/MacOS.html \
		content/Download/Binaries/Windows.html
