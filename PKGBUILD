# Maintainer: Ozan Özdil <ozan@pm.me>
pkgname=omarchy-omacom-news
pkgver=1.1.0
pkgrel=1
pkgdesc="Official Omacom Foundation news dispatches and notification engine for Omarchy Linux"
arch=('x86_64')
url="https://github.com/ozdil/omarchy-omacom-news"
license=('MIT')
depends=('glibc' 'libnotify' 'curl')
makedepends=('cargo' 'rust')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
  cd "$pkgname-$pkgver"
  cargo build --release --locked
}

package() {
  cd "$pkgname-$pkgver"
  install -Dm755 target/release/omacomnews-engine "$pkgdir/usr/lib/omarchy/plugins/omacom-news/omacomnews-engine"
  install -Dm755 omacomnews-status "$pkgdir/usr/lib/omarchy/plugins/omacom-news/omacomnews-status"
  install -Dm755 omacomnews-dashboard "$pkgdir/usr/lib/omarchy/plugins/omacom-news/omacomnews-dashboard"
  install -Dm644 Panel.qml "$pkgdir/usr/lib/omarchy/plugins/omacom-news/Panel.qml"
  install -Dm644 manifest.json "$pkgdir/usr/lib/omarchy/plugins/omacom-news/manifest.json"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
