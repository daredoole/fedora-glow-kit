Name:           fedora-glow-kit
Version:        1.0.0
Release:        1%{?dist}
Summary:        Safe, reversible Fedora KDE and GNOME setup manager
License:        MIT
URL:            https://github.com/daredoole/fedora-glow-kit
Source0:        %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  desktop-file-utils
BuildRequires:  python3
BuildRequires:  python3-pyside6
BuildRequires:  python3-rpm-macros
Requires:       bash
Requires:       python3
Requires:       python3-pyside6
Requires:       qt6-qtdeclarative
Requires:       desktop-file-utils
Recommends:     gnome-shell-extension-appindicator

%description
Fedora Glow Kit provides reviewed shell installers and reversible desktop
profiles. It includes local-only diagnostics plus an optional Qt control deck
and tray helper for Fedora 44 KDE Plasma and GNOME Workstation.

%prep
%autosetup -n %{name}-%{version}

%build

%install
mkdir -p \
  %{buildroot}%{python3_sitelib} \
  %{buildroot}%{_bindir} \
  %{buildroot}%{_datadir}/fedora-plasma-glow-kit \
  %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/icons/hicolor/scalable/apps

cp -a glow_kit %{buildroot}%{python3_sitelib}/
install -m 0755 bin/glow-kit bin/glow-kit-gui %{buildroot}%{_bindir}/
install -m 0644 packaging/fedora-glow-kit.desktop \
  %{buildroot}%{_datadir}/applications/fedora-glow-kit.desktop
install -m 0644 assets/fedora-glow-kit.svg \
  %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/fedora-glow-kit.svg
install -Dm 0644 packaging/glow-kit.1 \
  %{buildroot}%{_mandir}/man1/glow-kit.1
install -Dm 0644 packaging/glow-kit-gui.1 \
  %{buildroot}%{_mandir}/man1/glow-kit-gui.1

cp -a \
  configs docs lib profiles scripts shell \
  install.sh install-ai.sh install-extras.sh install-gnome.sh install-kde.sh \
  install-security.sh manage.sh revert.sh \
  %{buildroot}%{_datadir}/fedora-plasma-glow-kit/

desktop-file-validate \
  %{buildroot}%{_datadir}/applications/fedora-glow-kit.desktop

%check
PYTHONPATH=. python3 -m unittest discover -s tests -p 'test_*.py'
bash -n install*.sh manage.sh revert.sh lib/*.sh shell/*.sh scripts/*.sh bin/*

%files
%license LICENSE.md
%doc README.md CHANGELOG.md SECURITY.md
%{_bindir}/glow-kit
%{_bindir}/glow-kit-gui
%{_mandir}/man1/glow-kit.1*
%{_mandir}/man1/glow-kit-gui.1*
%{python3_sitelib}/glow_kit/
%{_datadir}/applications/fedora-glow-kit.desktop
%{_datadir}/icons/hicolor/scalable/apps/fedora-glow-kit.svg
%{_datadir}/fedora-plasma-glow-kit/

%changelog
* Tue Jul 28 2026 Fedora Glow Kit maintainers <noreply@example.invalid> - 1.0.0-1
- Initial production package with CLI, GUI, tray, and reversible desktop profiles
