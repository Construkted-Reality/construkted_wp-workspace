# TDD Workflow Rules

## The Cycle: Red → Green → Refactor

1. **Red.** Write one test for behavior that doesn't exist. Run it. It must fail.
2. **Green.** Write the minimum code to pass the test. Nothing more.
3. **Refactor.** Clean up while tests stay green. Then write the next test.

Each cycle should take minutes, not hours.

## Rules

- **Test first, always.** The test defines the behavior before the code exists. No exceptions for "simple" code.
- **One test at a time.** Don't write a batch of tests then implement. Build spec and implementation in lockstep.
- **Test what you touch.** Every PR that modifies code must include tests for that code. No retroactive coverage sprints.
- **Characterize before refactoring.** Changing untested legacy code? Write tests capturing current behavior first, then refactor under that safety net.
- **Don't test other people's libraries.** Test your logic, not that CesiumJS/WordPress/Express work correctly.
- **Don't test glue code.** One-line wrappers, hook registrations, and trivial delegation add no test value.
- **Keep unit and integration tests separate.** Distinct test suites, distinct scripts (`test:unit`, `test:integration`). Unit tests must run fast with zero infrastructure.
- **A failing test is a feature, not a problem.** It means you found a gap before your users did.
