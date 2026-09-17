config_vala = configure_file(
  input: 'config.vala.in',
  output: 'config.vala',
  configuration: {
    'APP_ID': app_id,
    'VERSION': meson.project_version(),
    'GETTEXT_PACKAGE': gettext_package,
    'LOCALEDIR': get_option('prefix') / get_option('localedir'),
    'RESOURCE_PATH': resource_path,
  },
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')

# GTK-free engine: models, scanning, and trash orchestration. Depends only
# on GLib/GObject/Gio so it can be unit-tested headlessly and reused as-is
# by the GTK application below.
engine_sources = files(
  'models/candidate-file.vala',
  'models/duplicate-group.vala',
  'models/empty-folder.vala',
  'models/selection-summary.vala',
  'util/path-display.vala',
  'scanner.vala',
  'empty-folder-scanner.vala',
  'trash-operation.vala',
)

libganitor_engine = static_library(
  'ganitor-engine',
  [config_vala, engine_sources],
  dependencies: [glib_dep, gobject_dep, gio_dep],
  vala_header: 'ganitor-engine.h',
  vala_vapi: 'ganitor-engine.vapi',
  install: false,
)

libganitor_engine_dep = declare_dependency(
  link_with: libganitor_engine,
  include_directories: include_directories('.'),
  dependencies: [glib_dep, gobject_dep, gio_dep],
)

gtk_dep = dependency('gtk4')
adwaita_dep = dependency('libadwaita-1', version: '>= 1.5')

gnome = import('gnome')
resources = gnome.compile_resources(
  'ganitor-resources',
  'ganitor.gresource.xml',
  source_dir: '.',
  c_name: 'ganitor',
)

app_sources = files(
  'main.vala',
  'application.vala',
  'window.vala',
  'widgets/candidate-file-row.vala',
  'widgets/duplicate-group-row.vala',
  'widgets/empty-folder-row.vala',
)

executable(
  'ganitor',
  [app_sources, resources],
  dependencies: [libganitor_engine_dep, gtk_dep, adwaita_dep],
  install: true,
)
