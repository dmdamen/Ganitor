project('ganitor', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.62.0',
  license: 'GPL-3.0-or-later',
)

app_id = 'io.github.dmdamen.Ganitor'
gettext_package = meson.project_name()
resource_path = '/io/github/dmdamen/Ganitor'

i18n = import('i18n')
gnome = import('gnome')

subdir('data')
subdir('src')
subdir('tests')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
