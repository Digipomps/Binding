# HavenAgentD integration contracts

This directory contains the versioned, machine-readable contracts consumed by
other HAVEN repositories. Consumers must integrate through these contracts or
through released executables; they must not import HavenAgentD source files or
assume that the repository is nested inside Binding.

## Current contracts

- `registration-observation-v1.schema.json` defines the redacted observation
  returned inside the loopback onboarding status report and consumed by
  Binding's registration adapter.
- `registration-observation-v1.example.json` is a deterministic valid example
  for cross-repository compatibility tests.

Breaking changes require a new schema identifier and a new file. Additive
changes may be made only when existing consumers remain valid.
