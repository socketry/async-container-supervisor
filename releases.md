# Releases

## Unreleased

  - If a memory leak is detected, sample memory usage for 60 seconds before exiting.

## v0.6.4

  - Make client task (in supervised worker) transient, so that it doesn't keep the reactor alive unnecessarily. It also won't be stopped by default when SIGINT is received, so that the worker will remain connected to the supervisor until the worker is completely terminated.

## v0.6.3

  - Add agent context documentation.

## v0.6.2

  - Fix timed out RPCs and subsequent responses which should be ignored.

## v0.6.0

  - Add `async:container:supervisor:reload` command to restart the container (blue/green deployment).

## v0.1.0

  - Initial implementation.
