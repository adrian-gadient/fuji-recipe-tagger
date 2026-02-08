# Contributing

Thanks for your interest in contributing to fuji-recipe-tagger! Here's how to get started.

## Development Setup

This repo uses Docker for testing.  

### Option 1: Using Docker (Recommended)

Docker provides a consistent environment and is the easiest way to get started.

1. **Install Docker Desktop** for Mac:
   - Download from [docker.com](https://www.docker.com/products/docker-desktop/)
   - Open Docker Desktop and wait for it to start (whale icon in menu bar)

2. **Clone the repository**:
```bash
   git clone https://github.com/adrian-gadient/fuji-recipe-tagger.git
   cd fuji-recipe-tagger
```

3. **Build and run tests**:
```bash
   # Build the Docker image (first time only)
   docker compose build
   
   # Run tests
   docker compose run --rm bats
```

That's it! Docker handles all dependencies automatically.

### Option 2: Local Setup (macOS)

If you prefer running tests locally without Docker:

1. **Install dependencies**:
```bash
   brew install exiftool miller bats-core
```

2. **Clone the repository**:
```bash
   git clone https://github.com/adrian-gadient/fuji-recipe-tagger.git
   cd fuji-recipe-tagger
```

3. **Set up test helpers**:
```bash
   cd tests
   git clone https://github.com/bats-core/bats-support.git test_helper/bats-support
   git clone https://github.com/bats-core/bats-assert.git test_helper/bats-assert
   git clone https://github.com/bats-core/bats-file.git test_helper/bats-file
   cd ..
```

## Running Tests

### Using Docker
```bash
# Run all tests
docker compose run --rm bats

# Run specific test file
docker compose run --rm bats bats /code/tests/get_exif.bats

# Rebuild after changes to Dockerfile
docker compose build --no-cache
```

### Running Locally (if you chose Option 2)
```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/get_exif.bats
```

## Making Changes

1. **Create a branch** for your changes:
```bash
   git checkout -b feature/your-feature-name
```

2. **Make your changes** to the scripts in `scripts/macOS/`

3. **Test your changes**:
```bash
   # Using Docker (recommended)
   docker compose run --rm bats
   
   # Or locally
   bats tests/
```

4. **Verify tests pass** - All tests should pass before submitting

5. **Commit your changes**:
```bash
   git add .
   git commit -m "feat: description of your changes"
```

6. **Push and create a Pull Request**:
```bash
   git push origin feature/your-feature-name
```
   Then open a PR on GitHub

## Writing Tests

When adding new features, please add corresponding tests:
```bash
# Test files are in tests/ directory
tests/
├── add_recipes.bats
├── get_exif.bats
└── identify_recipes.bats

# Tests use bats syntax
@test "description of what this tests" {
  run bash "$SCRIPT_PATH" <<< "input"
  assert_success
  assert_output --partial "expected output"
}
```

## Coding Standards

- Use `#!/usr/bin/env bash` shebang
- Include `set -euo pipefail` for safety
- Add comments for complex logic
- Use descriptive variable names
- Test edge cases
- All scripts should work with drag-and-drop input

## CI/CD

All pull requests automatically run tests via GitHub Actions. You can see the results in the "Checks" tab of your PR.

The same Docker environment is used in CI, so if tests pass locally with Docker, they should pass in CI too.

## Reporting Issues

Found a bug or have a feature request?

- [Report a bug](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?template=bug_report.md)
- [Request a feature](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?labels=enhancement)
- [Ask a question](https://github.com/adrian-gadient/fuji-recipe-tagger/issues/new?labels=question)

## Project Structure
```
fuji-recipe-tagger/
├── scripts/macOS/       # Main scripts
├── tests/               # Test files
├── Dockerfile           # Docker configuration
├── docker-compose.yml   # Docker Compose setup
├── recipes.csv          # Example recipes
└── README.md           # Main documentation
```

## Questions?

Feel free to open an issue for any questions about contributing!
