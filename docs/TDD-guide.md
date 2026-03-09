# TDD Guide for Construkted Reality

## What TDD Is

Test-Driven Development means writing a failing test before writing the code that makes it pass. The test defines the expected behavior. The code fulfills it. This reversal — spec before implementation — forces you to think about what code should do before thinking about how.

## The Cycle: Red → Green → Refactor

Every change follows this loop:

1. **Red.** Write one test for a behavior that doesn't exist yet. Run it. It must fail. If it passes, your test isn't testing anything new.
2. **Green.** Write the *minimum* code to make that one test pass. Not elegant. Not complete. Just enough to go green.
3. **Refactor.** Now clean up — rename, extract methods, remove duplication — while all tests stay green. The passing tests are your safety net.

Repeat. Each cycle takes minutes. You are building the specification and the implementation together, one behavior at a time. Don't write a batch of tests up front and then implement — that defeats the feedback loop.

## Rules

**Test first, always.** No exceptions for "obvious" or "simple" code. If it has logic, it gets a test before it gets an implementation.

**Test what you touch.** Every PR that modifies code must include tests for that code. We do not pursue coverage retroactively. Untouched stable code doesn't need tests added in a sprint — tests go where active changes go, because that's where bugs are introduced.

**Characterize before refactoring.** When you need to change legacy code that has no tests, write tests that capture its *current behavior* first — even if that behavior is buggy. These characterization tests become your safety net. Fix bugs in a separate step, after the safety net is in place.

**Test your code, not the libraries.** Don't write tests verifying that CesiumJS, Express, or WordPress work. Test the logic *you wrote* that uses them. If your function is a one-line delegation to a library, there's nothing of yours to test.

**Keep suites separate.** Unit tests and integration tests live in separate directories with separate scripts (`test:unit`, `test:integration`). Unit tests must run fast with zero infrastructure — no database, no Docker, no network. Integration tests can require infrastructure and run in CI.

## What Not to TDD

Not everything benefits from test-first development:

- **Exploratory/prototype code** where you don't yet know the interface. Spike first, then write tests when the design stabilizes.
- **Rendering and visual output.** "Does it look right" can't be expressed as a unit test assertion. Use visual regression (screenshot comparison) or structured manual QA instead.
- **Thin glue code.** Hook registrations, one-line wrappers, trivial delegation — if there's no branching logic, there's nothing meaningful to assert.

## The Short Version

Write the test. Watch it fail. Make it pass. Clean up. Repeat. Do this for every change, starting now.

See [TDD-rules.md](TDD-rules.md) for the quick-reference version.
