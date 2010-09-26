#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

ITCLVERS="3.4"
ITCLVERSEXTRA="b1"
SRC="src/itcl-${ITCLVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/incrtcl/files/%5BIncr%20Tcl_Tk%5D-source/${ITCLVERS}/itcl${ITCLVERS}${ITCLVERSEXTRA}.tar.gz/download"
BUILDDIR="$(pwd)/build/itcl${ITCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export ITCLVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}" || exit 1
	./configure --enable-shared --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

	"${MAKE:-make}" || exit 1

	"${MAKE:-make}" install

	mkdir "${OUTDIR}/lib" || exit 1
	cp -r "${INSTDIR}/lib"/itcl*/ "${OUTDIR}/lib/"
) || exit 1

exit 0
