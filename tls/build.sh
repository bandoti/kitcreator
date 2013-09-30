#! /usr/bin/env bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

TLSVERS="1.6"
SRC="src/tls-${TLSVERS}.tar.gz"
SRCURL="http://sourceforge.net/projects/tls/files/tls/${TLSVERS}/tls${TLSVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tls${TLSVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHDIR="$(pwd)/patches"
export TLSVERS SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHDIR

# Set configure options for this sub-project
LDFLAGS="${KC_TLS_LDFLAGS}"
CFLAGS="${KC_TLS_CFLAGS}"
CPPFLAGS="${KC_TLS_CPPFLAGS}"
LIBS="${KC_TLS_LIBS}"
export LDFLAGS CFLAGS CPPFLAGS LIBS

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

TCL_VERSION="unknown"
if [ -f "${TCLCONFIGDIR}/tclConfig.sh" ]; then
        source "${TCLCONFIGDIR}/tclConfig.sh"
fi
export TCL_VERSION

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if [ ! -d 'buildsrc' ]; then
		rm -f "${SRC}.tmp"
		wget -O "${SRC}.tmp" "${SRCURL}" || exit 1
		mv "${SRC}.tmp" "${SRC}"
	fi
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else    
		cp -rp ../buildsrc/* './'
	fi

	# Apply required patches
	cd "${BUILDDIR}" || exit 1
	for patch in "${PATCHDIR}/all"/tls-${TLSVERS}-*.diff "${PATCHDIR}/${TCL_VERSION}"/tls-${TLSVERS}-*.diff; do
		if [ ! -f "${patch}" ]; then
			continue
		fi

		echo "Applying: ${patch}"
		${PATCH:-patch} -p1 < "${patch}"
	done

	cd "${BUILDDIR}" || exit 1

	# Try to build as a shared object if requested
	if [ "${STATICTLS}" = "0" ]; then
		tryopts="--enable-shared --disable-shared"
	elif [ "${STATICTLS}" = "-1" ]; then
		tryopts="--enable-shared"
	else
		tryopts="--disable-shared"
	fi

	SAVE_CFLAGS="${CFLAGS}"
	for tryopt in $tryopts __fail__; do
		# Clean up, if needed
		make distclean >/dev/null 2>/dev/null
		rm -rf "${INSTDIR}"
		mkdir "${INSTDIR}"

		if [ "${tryopt}" = "__fail__" ]; then
			exit 1
		fi

		if [ "${tryopt}" == "--enable-shared" ]; then
			isshared="1"
		else
			isshared="0"
		fi

		# If build a static TLS for KitDLL, ensure that we use PIC
		# so that it can be linked into the shared object
		if [ "${isshared}" = "0" -a "${KITTARGET}" = "kitdll" ]; then
			CFLAGS="${SAVE_CFLAGS} -fPIC"
		else
			CFLAGS="${SAVE_CFLAGS}"
		fi
		export CFLAGS

		if [ "${isshared}" = '0' ]; then
			sed 's@USE_TCL_STUBS@XXX_TCL_STUBS@g' configure > configure.new
		else
			sed 's@XXX_TCL_STUBS@USE_TCL_STUBS@g' configure > configure.new
		fi
		cat configure.new > configure
		rm -f configure.new

		(
			echo "Running: ./configure $tryopt --prefix=\"${INSTDIR}\" --exec-prefix=\"${INSTDIR}\" --libdir=\"${INSTDIR}/lib\" --with-tcl=\"${TCLCONFIGDIR}\" ${CONFIGUREEXTRA}"
			./configure $tryopt --prefix="${INSTDIR}" --exec-prefix="${INSTDIR}" --libdir="${INSTDIR}/lib" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\""
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" || exit 1

			echo "Running: ${MAKE:-make} tcllibdir=\"${INSTDIR}/lib\" AR=\"${AR:-ar}\" RANLIB=\"${RANLIB:-ranlib}\" install"
			${MAKE:-make} tcllibdir="${INSTDIR}/lib" AR="${AR:-ar}" RANLIB="${RANLIB:-ranlib}" install || exit 1
		) || continue

		break
	done

	# Create pkgIndex if needed
	if [ ! -e "${INSTDIR}/lib/tls${TLSVERS}/pkgIndex.tcl" ]; then
		cat << _EOF_ > "${INSTDIR}/lib/tls${TLSVERS}/pkgIndex.tcl"
package ifneeded tls ${TLSVERS} \
    "[list source [file join \$dir tls.tcl]] ; \
     [list load {} tls]"
_EOF_
	fi

	# Install files needed by installation
	cp -r "${INSTDIR}/lib" "${OUTDIR}" || exit 1
	find "${OUTDIR}" -name '*.a' -type f | xargs -n 1 rm -f --

	## XXX: TODO: Determine what we actually need to link against
	echo '-lssl -lcrypto' > "${INSTDIR}/lib/tls${TLSVERS}/libtls${TLSVERS}.a.linkadd"

	exit 0
) || exit 1

exit 0