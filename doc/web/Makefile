# This Makefile requires that `pandoc` be installed:
#     https://pandoc.org
# and Python:
#     https://python.org


# convert each Markdown source file to an HTML file for the website
html_from_md:
	python generate_html.py

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
