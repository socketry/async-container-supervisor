# Process Monitor Example

This example demonstrates how to use the `ProcessMonitor` to log process metrics periodically for all worker processes.

## Overview

The `ProcessMonitor` captures CPU and memory metrics for the entire process tree by tracking the parent process ID (ppid). This is more efficient than tracking individual processes and provides a comprehensive view of resource usage across all workers.

## Usage

Run the service:

```bash
$ ./service.rb
```

This will:
1. Start a supervisor process.
2. Spawn 4 worker processes that perform CPU and memory work.
3. Log process metrics every 10 seconds.
4. Monitor memory usage and restart workers that exceed 500MB.
