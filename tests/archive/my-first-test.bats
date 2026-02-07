#!/usr/bin/env bats

load '/opt/bats-helpers/bats-support/load'
load '/opt/bats-helpers/bats-assert/load'

@test "It Works" {
    # Arrange
    # Prepare "the world" for your test

    # Act
    # Run your code
    result="$(echo 2+2 | bc)"

    # Assert
    # Make assertions to ensure that the code does what it should
    [ "$result" -eq 4 ]
}