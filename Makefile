# Run local instnace w/o drafts.
default:
	hugo server

# Run local instance w/ drafts
.PHONY: drafts
drafts:
	hugo server --buildDrafts

# Upload static files to Cloud Files.
.PHONY: up
up: build
	swiftly put --newer -i public blog.hurricanerix.me

# Build static files
.PHONY: clean build
build:
	hugo

# Remove local static files
.PHONY: clean
clean:
	rm -rf public/*

# Remove remote objects from Cloud Files
.PHONY: clean-up
clean-up:
	swiftly get blog.hurricanerix.me | while read i; do swiftly delete blog.hurricanerix.me/$i; done
