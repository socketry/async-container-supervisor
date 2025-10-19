# Async::Container::Supervisor

Provides a supervisor service for

[![Development Status](https://github.com/socketry/async-container-supervisor/workflows/Test/badge.svg)](https://github.com/socketry/async-container-supervisor/actions?workflow=Test)

## Features

  - Supports multi-process, multi-thread and hybrid containers.
  - Automatic scalability based on physical hardware.
  - Direct integration with [systemd](https://www.freedesktop.org/software/systemd/man/sd_notify.html) using `$NOTIFY_SOCKET`.
  - Internal process readiness protocol for handling state changes.
  - Automatic restart of failed processes.

## Usage

Please see the [project documentation](https://socketry.github.io/async-container-supervisor/) for more details.

  - [Getting Started](https://socketry.github.io/async-container-supervisor/guides/getting-started/index) - This guide explains how to get started with `async-container-supervisor` to supervise and monitor worker processes in your Ruby applications.

## Releases

Please see the [project releases](https://socketry.github.io/async-container-supervisor/releases/index) for all releases.

### v0.6.4

  - Make client task (in supervised worker) transient, so that it doesn't keep the reactor alive unnecessarily. It also won't be stopped by default when SIGINT is received, so that the worker will remain connected to the supervisor until the worker is completely terminated.

### v0.6.3

  - Add agent context documentation.

### v0.6.2

  - Fix timed out RPCs and subsequent responses which should be ignored.

### v0.6.0

  - Add `async:container:supervisor:reload` command to restart the container (blue/green deployment).

### v0.1.0

  - Initial implementation.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
