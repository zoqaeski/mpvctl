# Maintainer: Robbie Smith <zoqaeski AT gmail DOT com>

pkgname=mpvctl
pkgver=1.0
pkgrel=1
pkgdesc="Shell script to control a long-running mpv from the command line."
arch=('any')
url="https://github.com/zoqaeski/mpvctl"
license=('MIT')
depends=('mpv' 'zsh' 'socat' 'jq')
source=('mpvctl.desktop'
        'mpvctl.zsh'
        'LICENSE'
        'README.md')
sha256sums=('b2b4da47722eef74f04623e8dc38b6ac38085685d96b0e804e64216cefa39e31'
            '509481910bf7d7876f7794958578cdbbf263431a1335839092c23b7ce28257e1'
            '4117447cc5b8ce70bae87bdb7e700ce16aef050c8ac12586a8780b0ddbcacb61'
            '27e85c85d23d74ed0844b930901440490ef4d856cbaa43713cdbd51f5f37cc5d')

package() {
  cd "$srcdir"
  install -Dm755 ${pkgname}.zsh              "$pkgdir/usr/bin/${pkgname}"
  install -Dm644 ${pkgname}.desktop          "$pkgdir/usr/share/applications/${pkgname}.desktop"
  install -Dm644 LICENSE                     "$pkgdir/usr/share/licenses/${pkgname}/LICENSE"
  install -Dm644 README.md                   "$pkgdir/usr/share/doc/${pkgname}/README"
}
