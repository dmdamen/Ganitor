# Unit test binaries are added here as they are written (TDD: the test file
# is written and registered before the engine code it exercises).

test_fixtures = files('test-fixtures.vala')

test_candidate_file = executable(
  'test-candidate-file',
  [test_fixtures, 'test-candidate-file.vala'],
  dependencies: [libganitor_engine_dep],
)
test('candidate-file', test_candidate_file)

test_duplicate_group = executable(
  'test-duplicate-group',
  [test_fixtures, 'test-duplicate-group.vala'],
  dependencies: [libganitor_engine_dep],
)
test('duplicate-group', test_duplicate_group)

test_format = executable(
  'test-format',
  'test-format.vala',
  dependencies: [libganitor_engine_dep],
)
test('format', test_format)

test_selection_summary = executable(
  'test-selection-summary',
  [test_fixtures, 'test-selection-summary.vala'],
  dependencies: [libganitor_engine_dep],
)
test('selection-summary', test_selection_summary)

test_scanner = executable(
  'test-scanner',
  [test_fixtures, 'test-scanner.vala'],
  dependencies: [libganitor_engine_dep],
)
test('scanner', test_scanner)

test_trash_operation = executable(
  'test-trash-operation',
  [test_fixtures, 'test-trash-operation.vala'],
  dependencies: [libganitor_engine_dep],
)
test('trash-operation', test_trash_operation)
