#!/bin/sh
set -e

die() {
	echo "$1"
	exit 1
}

check_command() {
	command -v "$1" > /dev/null || die "No $1 executable in PATH. Cannot continue."
}


# Validate environment in which this script is running
check_command apk
check_command grep
check_command cat
apk --help | grep -F fetch > /dev/null || die 'apk does not support fetching packages from remote repositories'  # apk supports fetch
apk --help | grep -F index > /dev/null || die 'apk does not support indexing .apk files for APKINDEX.tar.gz creation' # apk supports index


usage() {
	cat <<EOF

Creates a repository to be used for the 'mkimage.sh' script available in the aports repository based
on the package configuration found in 'packages'

$0	[--outdir OUTDIR] [--arch ARCH] [--use-also APK_FILE].. [--fetch-edge FETCH_EDGE_FILE]..
$0	--help

options:
--fetch-edge            File containing a list of packages that should be fetched for Alpine's offical edge channel.
--outdir		Where the repository should be created at
--use-also              Adds the given apk file to the generated repository. Can be specified multiple times.
EOF
}


# Parse Parameters
USE_ALSO=""
FETCH_EDGE_FILES=""
while [ $# -gt 0 ] ; do
	opt=$1
	shift
	case "$opt" in
		--outdir) OUTDIR="$1"; shift ;;
		--use-also) USE_ALSO="$1 $USE_ALSO"; shift ;;
		--fetch-edge) FETCH_EDGE_FILES="$1 $FETCH_EDGE_FILES"; shift ;;
		--*) usage; exit 1 ;;
	esac
done

# Validate parameters
[ ! -z $OUTDIR ] || die 'Parameter --outdir not specified. See --help for more information.'
[ ! -e $OUTDIR ] || die 'Outdir already exists! This is not allowed' 

# Validate use-also packages
# TODO For now, they just need to exist
for also in $USE_ALSO; do
	[ -f "$also" ] || die "Apk package $also does not exist!"
done

# Printing configuration
ARCH="$(apk --print-arch)"
echo "Architecture is: $ARCH"
for also in $USE_ALSO; do
	echo "Use also APK: ${also}"
done

# Assemble package lists
if [ -z $FETCH_EDGE_FILES ]; then
	FETCH_EDGE_PACKAGES=""
else
	FETCH_EDGE_PACKAGES=$(cat $FETCH_EDGE_FILES)
fi

# TODO Assemble List for use_also

# TODO Check for conflicting packages (by name)


# Perform installation of packages
DEST="${OUTDIR}/$ARCH"
mkdir -p ${DEST}

# Get the packages via FETCH_EDGE
cd "$DEST"
apk fetch -q --arch $ARCH --no-cache -U --repository "http://dl-cdn.alpinelinux.org/alpine/edge/main" $FETCH_EDGE_PACKAGES
sync

# Get the packages for --use-also
for also in $USE_ALSO; do
	cp $also $DEST
done
sync

echo 'Creating index...'

# Create the package index
apk index --no-cache -U --arch $ARCH --rewrite-arch $ARCH -o APKINDEX.tar.gz *.apk
sync


