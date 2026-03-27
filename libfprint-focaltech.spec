Name:           libfprint-focaltech
Version:        1.94.4
Release:        2.tod1%{?dist}
Summary:        Fingerprint reader library with FocalTech FT9201/FT9338 driver (TOD build)
License:        LGPLv2+ and Proprietary
URL:            https://github.com/ryenyuku/libfprint-ft9201

# Source: Ubuntu TOD-enabled deb extracted to build dir
# ar x libfprint-2-2_1.94.4+tod1-0ubuntu1.22.04.2_amd64_20250219.deb && tar xf data.tar.*

# This package replaces the standard libfprint with the Focal-systems TOD build
# which includes a built-in driver for FocalTech FT9201/FT9338 (USB 2808:9338)
Obsoletes:      libfprint < 1.95
Provides:       libfprint = %{version}-%{release}
Provides:       libfprint-2.so.2()(64bit)

Requires:       glib2
Requires:       libgusb
Requires:       libgudev
Requires:       nss
Requires:       pixman
Requires:       libusb1

%description
A TOD (Touch OEM Driver) build of libfprint that includes a built-in driver
for FocalTech FT9201/FT9338 fingerprint sensors (USB vendor 0x2808).
This replaces the standard libfprint package. Intended for the GPD Win 4
and similar devices with the FocalTech fingerprint reader.

%global filesdir %{_topdir}/BUILD

%install
mkdir -p %{buildroot}%{_libdir}
install -m 755 %{filesdir}/libfprint-2.so.2.0.0 %{buildroot}%{_libdir}/libfprint-2.so.2.0.0
ln -s libfprint-2.so.2.0.0 %{buildroot}%{_libdir}/libfprint-2.so.2
ln -s libfprint-2.so.2.0.0 %{buildroot}%{_libdir}/libfprint-2.so

mkdir -p %{buildroot}%{_prefix}/lib/udev/rules.d
install -m 644 %{filesdir}/60-libfprint-2.rules %{buildroot}%{_prefix}/lib/udev/rules.d/60-libfprint-2.rules

%post
/sbin/ldconfig
udevadm control --reload-rules 2>/dev/null || true

%postun
/sbin/ldconfig

%files
%{_libdir}/libfprint-2.so.2.0.0
%{_libdir}/libfprint-2.so.2
%{_libdir}/libfprint-2.so
%{_prefix}/lib/udev/rules.d/60-libfprint-2.rules
