desktop_file = configure_file(
  input: app_id + '.desktop.in',
  output: app_id + '.desktop',
  copy: true,
)
install_data(desktop_file, install_dir: get_option('datadir') / 'applications')

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('validate-desktop', desktop_utils, args: [desktop_file])
endif

metainfo_file = configure_file(
  input: app_id + '.metainfo.xml.in',
  output: app_id + '.metainfo.xml',
  copy: true,
)
install_data(metainfo_file, install_dir: get_option('datadir') / 'metainfo')

appstream_util = find_program('appstreamcli', required: false)
if appstream_util.found()
  test('validate-metainfo', appstream_util, args: ['validate', '--no-net', metainfo_file])
endif

install_data(
  app_id + '.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('validate-schema', compile_schemas, args: ['--strict', '--dry-run', meson.current_source_dir()])
endif

install_data(
  'icons' / 'hicolor' / 'scalable' / 'apps' / app_id + '.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)

install_data(
  'icons' / 'hicolor' / 'symbolic' / 'apps' / app_id + '-symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
)
